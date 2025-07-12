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
  // TODO: [AdjustmentDistortion] Default face effect range (0.2 = small area, 0.6 = large area)
  @Published var faceEffectRange: Double = 0.35
  @Published var isSaving = false
  @Published var showShareSheet = false
  @Published var permissionGranted = false
  @Published var showRangeIndicator = false
  @Published var rangeIndicatorSize: CGFloat = 100
  @Published var rangeIndicatorPosition: CGPoint = .zero

  let cameraService = CameraService()
  private let faceDetector = FaceDetector()
  private let shoulderDetector = ShoulderDetector()
  private let imageWarper = ImageWarper()
  
  private var detectedFaceRect: CGRect?
  private var imageDisplayScale: CGFloat = 1.0

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
          self.detectedFaceRect = faceRect
          print("Applying warp with intensity: \(self.effectIntensity), range: \(self.faceEffectRange)")
          self.processedImage = imageWarper.warpImage(
            image,
            faceRect: faceRect,
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
  
  func updateRangeIndicator() {
    guard let faceRect = detectedFaceRect,
          let image = capturedImage else { return }
    
    // Calculate display scale based on image aspect ratio
    // This is simplified - in real app would need to match image display in EditingView
    let displayScale = min(UIScreen.main.bounds.width / image.size.width,
                          UIScreen.main.bounds.height / image.size.height)
    
    imageDisplayScale = displayScale
    
    // Convert face rect to screen coordinates
    let screenFaceCenter = CGPoint(
      x: faceRect.midX * displayScale,
      y: faceRect.midY * displayScale
    )
    
    rangeIndicatorPosition = screenFaceCenter
    rangeIndicatorSize = faceRect.width * displayScale * CGFloat(faceEffectRange * 2)
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
