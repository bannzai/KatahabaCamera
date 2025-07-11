import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class ImageWarper {
  private let context = CIContext()

  func warpImage(_ image: UIImage, faceRect: CGRect, shoulderMask: CIImage, intensity: CGFloat) -> UIImage? {
    guard let inputCIImage = CIImage(image: image) else { return nil }

    let baseFaceScale: CGFloat = 0.65
    let baseShoulderScale: CGFloat = 1.25

    let faceScale = 1.0 - (1.0 - baseFaceScale) * intensity
    let shoulderScale = 1.0 + (baseShoulderScale - 1.0) * intensity

    let scaledFaceImage = applyFaceScaling(to: inputCIImage, faceRect: faceRect, scale: faceScale)

    let finalImage = applyShoulderScaling(
      to: scaledFaceImage,
      shoulderMask: shoulderMask,
      faceRect: faceRect,
      scale: shoulderScale,
      originalSize: image.size
    )

    guard let outputCGImage = context.createCGImage(finalImage, from: finalImage.extent) else {
      return nil
    }

    return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
  }

  private func applyFaceScaling(to image: CIImage, faceRect: CGRect, scale: CGFloat) -> CIImage {
    let faceCenterX = faceRect.midX
    let faceCenterY = faceRect.midY

    let transform = CGAffineTransform(translationX: -faceCenterX, y: -faceCenterY)
      .scaledBy(x: scale, y: scale)
      .translatedBy(x: faceCenterX, y: faceCenterY)

    let scaledFaceImage = image.transformed(by: transform)

    let radialGradient = CIFilter.radialGradient()
    radialGradient.center = CGPoint(x: faceCenterX, y: faceCenterY)
    radialGradient.radius0 = Float(faceRect.width * 0.3)
    radialGradient.radius1 = Float(faceRect.width * 0.6)

    guard let gradientMask = radialGradient.outputImage else { return image }

    let blendFilter = CIFilter.blendWithMask()
    blendFilter.inputImage = scaledFaceImage
    blendFilter.backgroundImage = image
    blendFilter.maskImage = gradientMask

    return blendFilter.outputImage ?? image
  }

  private func applyShoulderScaling(to image: CIImage, shoulderMask: CIImage, faceRect: CGRect, scale: CGFloat, originalSize: CGSize) -> CIImage {
    let resizedMask = shoulderMask.transformed(by: CGAffineTransform(
      scaleX: originalSize.width / shoulderMask.extent.width,
      y: originalSize.height / shoulderMask.extent.height
    ))

    let faceAreaMask = createInverseFaceMask(faceRect: faceRect, imageSize: originalSize)

    let combinedMask = CIFilter.multiply()
    combinedMask.inputImage = resizedMask
    combinedMask.backgroundImage = faceAreaMask

    guard let shoulderOnlyMask = combinedMask.outputImage else { return image }

    let imageCenterX = image.extent.width / 2
    let imageCenterY = image.extent.height / 2

    let horizontalTransform = CGAffineTransform(translationX: -imageCenterX, y: -imageCenterY)
      .scaledBy(x: scale, y: 1.0)
      .translatedBy(x: imageCenterX, y: imageCenterY)

    let scaledImage = image.transformed(by: horizontalTransform)

    let blendFilter = CIFilter.blendWithMask()
    blendFilter.inputImage = scaledImage
    blendFilter.backgroundImage = image
    blendFilter.maskImage = shoulderOnlyMask

    return blendFilter.outputImage ?? image
  }

  private func createInverseFaceMask(faceRect: CGRect, imageSize: CGSize) -> CIImage {
    let color = CIColor(red: 1, green: 1, blue: 1)
    let whiteImage = CIImage(color: color).cropped(to: CGRect(origin: .zero, size: imageSize))

    let expandedFaceRect = faceRect.insetBy(dx: -faceRect.width * 0.3, dy: -faceRect.height * 0.3)

    let radialGradient = CIFilter.radialGradient()
    radialGradient.center = CGPoint(x: expandedFaceRect.midX, y: expandedFaceRect.midY)
    radialGradient.radius0 = Float(expandedFaceRect.width * 0.5)
    radialGradient.radius1 = Float(expandedFaceRect.width * 0.7)
    radialGradient.color0 = CIColor(red: 0, green: 0, blue: 0)
    radialGradient.color1 = CIColor(red: 1, green: 1, blue: 1)

    guard let gradient = radialGradient.outputImage else { return whiteImage }

    return gradient.cropped(to: CGRect(origin: .zero, size: imageSize))
  }
}
