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

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

      do {
        try handler.perform([request])
      } catch {
        continuation.resume(throwing: DetectionError.segmentationFailed)
      }
    }
  }
}
