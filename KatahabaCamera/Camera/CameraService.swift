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
        
        Task { @MainActor in
            self.photo = image
        }
    }
}