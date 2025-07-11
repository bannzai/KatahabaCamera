import UIKit
import Vision

actor FaceDetector {
    
    enum DetectionError: Error {
        case noFaceDetected
        case detectionFailed
        case imageConversionFailed
    }
    
    func detectFace(in image: UIImage) async throws -> CGRect {
        guard let cgImage = image.cgImage else {
            throw DetectionError.imageConversionFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: DetectionError.detectionFailed)
                    return
                }
                
                guard let results = request.results as? [VNFaceObservation],
                      let face = results.first else {
                    continuation.resume(throwing: DetectionError.noFaceDetected)
                    return
                }
                
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                let faceRect = self.convertRect(face.boundingBox, toImageSize: imageSize)
                continuation.resume(returning: faceRect)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: DetectionError.detectionFailed)
            }
        }
    }
    
    private func convertRect(_ rect: CGRect, toImageSize imageSize: CGSize) -> CGRect {
        let x = rect.origin.x * imageSize.width
        let y = (1 - rect.origin.y - rect.height) * imageSize.height
        let width = rect.width * imageSize.width
        let height = rect.height * imageSize.height
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
}