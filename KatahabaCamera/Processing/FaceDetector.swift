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

        print("Face observation boundingBox: \(face.boundingBox)")
        
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var faceRect = self.convertRect(face.boundingBox, toImageSize: imageSize, orientation: image.imageOrientation)
        
        // Expand face rect to include more area around the face
        // TODO: [AdjustmentDistortion] Adjust expansion factor (1.0 = original size, 2.0 = double size)
        let expansionFactor: CGFloat = 1.2  // 20% larger
        let widthExpansion = faceRect.width * (expansionFactor - 1.0) / 2.0
        let heightExpansion = faceRect.height * (expansionFactor - 1.0) / 2.0
        
        faceRect = CGRect(
          x: faceRect.origin.x - widthExpansion,
          y: faceRect.origin.y - heightExpansion,
          width: faceRect.width * expansionFactor,
          height: faceRect.height * expansionFactor
        )
        
        print("Converted face rect: \(faceRect)")
        print("Expanded face rect: \(faceRect)")
        continuation.resume(returning: faceRect)
      }

      // Create handler with proper orientation
      let orientation = self.cgImageOrientation(from: image.imageOrientation)
      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: DetectionError.detectionFailed)
      }
    }
  }

  private func convertRect(_ rect: CGRect, toImageSize imageSize: CGSize, orientation: UIImage.Orientation) -> CGRect {
    let x = rect.origin.x * imageSize.width
    let y = (1 - rect.origin.y - rect.height) * imageSize.height
    let width = rect.width * imageSize.width
    let height = rect.height * imageSize.height

    return CGRect(x: x, y: y, width: width, height: height)
  }
  
  private func cgImageOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
