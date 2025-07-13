import SwiftUI
import UIKit
import Combine
import Photos

@MainActor
class CameraViewModel: ObservableObject {
  @Published var capturedImage: UIImage?
  @Published var processedImage: UIImage?
  @Published var isShowingEditView = false
  // TODO: [AdjustmentDistortion] Default effect intensity (0.0 = no effect, 1.0 = maximum effect)
  @Published var effectIntensity: Double = 0.7
  // TODO: [AdjustmentDistortion] Default face effect range (0.1 = small area, 1.0 = large area)
  @Published var faceEffectRange: Double = 0.35
  @Published var isSaving = false
  @Published var showShareSheet = false
  @Published var permissionGranted = false
  @Published var showRangeIndicator = false
  @Published var rangeIndicatorSize: CGFloat = 100
  @Published var rangeIndicatorPosition: CGPoint = .zero
  @Published var faceCenterOffset: CGPoint = .zero // Offset from detected face center
  @Published var showCenterAdjustment = false

  let cameraService = CameraService()
  private let faceDetector = FaceDetector()
  private let shoulderDetector = ShoulderDetector()
  private let imageWarper = ImageWarper()
  
  private var detectedFaceRect: CGRect?
  private var imageDisplayScale: CGFloat = 1.0
  private var displaySize: CGSize = .zero
  private var displayOffset: CGPoint = .zero
  private var imageSize: CGSize = .zero

  private var cancellables = Set<AnyCancellable>()

  init() {
    cameraService.$photo
      .compactMap { $0 }
      .sink { [weak self] image in
        self?.capturedImage = image
        self?.isShowingEditView = true
        self?.processImage(image)
      }
      .store(in: &cancellables)
    
    cameraService.$permissionGranted
      .sink { [weak self] granted in
        self?.permissionGranted = granted
      }
      .store(in: &cancellables)
  }

  func capturePhoto() {
    cameraService.capturePhoto()
  }

  func processImage(_ image: UIImage) {
    Task {
      do {
        print("Processing image - size: \(image.size), orientation: \(image.imageOrientation.rawValue)")
        
        let faceRect = try await faceDetector.detectFace(in: image)
        print("Face detected at: \(faceRect)")
        
        let shoulderMask = try await shoulderDetector.detectShoulders(in: image)
        print("Shoulder mask generated")
        
        await MainActor.run {
          // For front camera mirrored images, adjust face rect X coordinate
          var adjustedFaceRect = faceRect
          if image.imageOrientation == .leftMirrored || image.imageOrientation == .rightMirrored ||
             image.imageOrientation == .upMirrored || image.imageOrientation == .downMirrored {
            adjustedFaceRect.origin.x = image.size.width - faceRect.origin.x - faceRect.width
          }
          
          self.detectedFaceRect = adjustedFaceRect
          print("Applying warp with intensity: \(self.effectIntensity), range: \(self.faceEffectRange)")
          
          // Apply center offset to face rect
          var offsetFaceRect = faceRect
          offsetFaceRect.origin.x += faceCenterOffset.x
          offsetFaceRect.origin.y += faceCenterOffset.y
          
          self.processedImage = imageWarper.warpImage(
            image,
            faceRect: offsetFaceRect,  // Use offset rect for processing
            shoulderMask: shoulderMask,
            intensity: CGFloat(effectIntensity),
            faceRange: CGFloat(faceEffectRange)
          )
          self.updateRangeIndicator()
          
          if self.processedImage != nil {
            print("Image processing completed successfully")
          }
        }
      } catch {
        print("Image processing error: \(error)")
        await MainActor.run {
          self.processedImage = image
        }
      }
    }
  }

  func updateEffectIntensity(_ intensity: Double) {
    effectIntensity = intensity
    if let capturedImage = capturedImage {
      processImage(capturedImage)
    }
  }
  
  func updateFaceEffectRange(_ range: Double) {
    faceEffectRange = range
    updateRangeIndicator()
    
    if let capturedImage = capturedImage {
      processImage(capturedImage)
    }
  }
  
  func updateFaceCenterOffset(_ offset: CGPoint) {
    faceCenterOffset = offset
    updateRangeIndicator()
    
    if let capturedImage = capturedImage {
      processImage(capturedImage)
    }
  }
  
  func updateRangeIndicator() {
    guard let faceRect = detectedFaceRect,
          displaySize.width > 0 else { return }
    
    // Calculate scale factor
    let scale = displaySize.width / imageSize.width
    
    // Convert face rect to screen coordinates with offset
    let screenFaceCenter = CGPoint(
      x: displayOffset.x + (faceRect.midX + faceCenterOffset.x) * scale,
      y: displayOffset.y + (faceRect.midY + faceCenterOffset.y) * scale
    )
    
    rangeIndicatorPosition = screenFaceCenter
    rangeIndicatorSize = faceRect.width * scale * CGFloat(faceEffectRange * 2)
  }
  
  func updateDisplayInfo(displaySize: CGSize, displayOffset: CGPoint, imageSize: CGSize, containerSize: CGSize? = nil) {
    self.displaySize = displaySize
    self.displayOffset = displayOffset
    self.imageSize = imageSize
    updateRangeIndicator()
  }

  func savePhoto() {
    guard let image = processedImage else { return }
    isSaving = true

    PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
      guard status == .authorized else {
        Task { @MainActor in
          self?.isSaving = false
        }
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        Task { @MainActor in
          self?.isSaving = false
          if success {
            self?.isShowingEditView = false
            self?.capturedImage = nil
            self?.processedImage = nil
          }
        }
      }
    }
  }

  func sharePhoto() {
    showShareSheet = true
  }

  func retake() {
    capturedImage = nil
    processedImage = nil
    isShowingEditView = false
  }
}
