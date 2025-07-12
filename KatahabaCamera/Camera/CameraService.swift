import AVFoundation
import UIKit
import Combine
import Vision
import Photos

@MainActor
class CameraService: NSObject, ObservableObject {
  @Published var isSessionRunning = false
  @Published var photo: UIImage?
  @Published var permissionGranted = false

  private let session = AVCaptureSession()
  private var output = AVCapturePhotoOutput()
  private var previewLayer: AVCaptureVideoPreviewLayer?

  override init() {
    super.init()
    checkPermission()
  }

  private func checkPermission() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      permissionGranted = true
      setupCamera()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        if granted {
          Task { @MainActor in
            self?.permissionGranted = true
            self?.setupCamera()
          }
        }
      }
    default:
      permissionGranted = false
    }
  }

  private func setupCamera() {
    session.beginConfiguration()

    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
      session.commitConfiguration()
      return
    }

    do {
      let input = try AVCaptureDeviceInput(device: device)
      if session.canAddInput(input) {
        session.addInput(input)
      }

      if session.canAddOutput(output) {
        session.addOutput(output)
        output.isHighResolutionCaptureEnabled = true
      }

      session.commitConfiguration()
      startSession()
    } catch {
      session.commitConfiguration()
      print("Camera setup error: \(error)")
    }
  }

  func startSession() {
    guard !session.isRunning else { return }

    Task(priority: .background) {
      session.startRunning()
      await MainActor.run {
        self.isSessionRunning = session.isRunning
      }
    }
  }

  func stopSession() {
    guard session.isRunning else { return }

    Task(priority: .background) {
      session.stopRunning()
      await MainActor.run {
        self.isSessionRunning = session.isRunning
      }
    }
  }

  func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
    let layer = AVCaptureVideoPreviewLayer(session: session)
    layer.videoGravity = .resizeAspectFill
    self.previewLayer = layer
    return layer
  }

  func capturePhoto() {
    let settings = AVCapturePhotoSettings()
    settings.flashMode = .off
    output.capturePhoto(with: settings, delegate: self)
  }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    guard let data = photo.fileDataRepresentation(),
          let image = UIImage(data: data) else { return }
    
    // Mirror the image for front camera
    let mirroredImage: UIImage
    if let cgImage = image.cgImage {
      let context = CIContext()
      let ciImage = CIImage(cgImage: cgImage)
      
      // Apply horizontal flip for front camera
      let flippedImage = ciImage.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        .transformed(by: CGAffineTransform(translationX: ciImage.extent.width, y: 0))
      
      if let outputCGImage = context.createCGImage(flippedImage, from: ciImage.extent) {
        mirroredImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
      } else {
        mirroredImage = image
      }
    } else {
      mirroredImage = image
    }

    Task { @MainActor in
      self.photo = mirroredImage
    }
  }
}
