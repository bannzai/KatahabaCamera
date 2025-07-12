import SwiftUI
import UIKit
import Combine
import Photos

@MainActor
class CameraViewModel: ObservableObject {
  @Published var capturedImage: UIImage?
  @Published var processedImage: UIImage?
  @Published var isShowingEditView = false
  @Published var effectIntensity: Double = 0.7
  @Published var isSaving = false
  @Published var showShareSheet = false
  @Published var permissionGranted = false

  let cameraService = CameraService()
  private let faceDetector = FaceDetector()
  private let shoulderDetector = ShoulderDetector()
  private let imageWarper = ImageWarper()

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
          print("Applying warp with intensity: \(self.effectIntensity)")
          self.processedImage = imageWarper.warpImage(
            image,
            faceRect: faceRect,
            shoulderMask: shoulderMask,
            intensity: CGFloat(effectIntensity)
          )
          
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
