import UIKit
import Vision
import CoreImage

actor ShoulderDetector {

  enum DetectionError: Error {
    case segmentationFailed
    case imageConversionFailed
  }

  func detectShoulders(in image: UIImage) async throws -> CIImage {
    guard let cgImage = image.cgImage else {
      throw DetectionError.imageConversionFailed
    }

    return try await withCheckedThrowingContinuation { continuation in
      let request = VNGeneratePersonSegmentationRequest { request, error in
        if let error = error {
          continuation.resume(throwing: DetectionError.segmentationFailed)
          return
        }

        guard let results = request.results as? [VNPixelBufferObservation],
              let segmentation = results.first else {
          continuation.resume(throwing: DetectionError.segmentationFailed)
          return
        }

        let maskImage = CIImage(cvPixelBuffer: segmentation.pixelBuffer)
        continuation.resume(returning: maskImage)
      }

      request.qualityLevel = .accurate

      // Create handler with proper orientation
      let orientation = self.cgImageOrientation(from: image.imageOrientation)
      let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: DetectionError.segmentationFailed)
      }
    }
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
