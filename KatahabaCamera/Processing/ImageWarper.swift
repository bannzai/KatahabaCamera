import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class ImageWarper {
  private let context = CIContext()

  func warpImage(_ image: UIImage, faceRect: CGRect, shoulderMask: CIImage, intensity: CGFloat) -> UIImage? {
    guard let inputCIImage = CIImage(image: image) else { return nil }

    // TODO: [AdjustmentDistortion] Base scale values (face: 0.65 = 35% smaller, shoulder: 1.25 = 25% wider)
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

    // Ensure the output image has the same extent as the input
    let outputExtent = inputCIImage.extent
    guard let outputCGImage = context.createCGImage(finalImage, from: outputExtent) else {
      return nil
    }

    return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
  }

  private func applyFaceScaling(to image: CIImage, faceRect: CGRect, scale: CGFloat) -> CIImage {
    let faceCenterX = faceRect.midX
    let faceCenterY = faceRect.midY
    
    print("Applying face scaling - center: (\(faceCenterX), \(faceCenterY)), scale: \(scale)")
    
    // Use torus lens distortion for more natural face shrinking
    let torusDistortion = CIFilter.torusLensDistortion()
    torusDistortion.inputImage = image
    torusDistortion.center = CGPoint(x: faceCenterX, y: faceCenterY)
    // TODO: [AdjustmentDistortion] Adjust radius (0.35 = 35% of face width)
    torusDistortion.radius = Float(faceRect.width * 0.35)
    // TODO: [AdjustmentDistortion] Adjust width (0.8 = 80% of radius)
    torusDistortion.width = Float(faceRect.width * 0.35 * 0.8)
    // TODO: [AdjustmentDistortion] Adjust refraction (-1.5 = inward distortion)
    torusDistortion.refraction = -1.5
    
    if let distorted = torusDistortion.outputImage {
      print("Torus distortion applied successfully")
      return distorted
    }
    
    // Fallback to pinch distortion if torus fails
    print("Falling back to pinch distortion")
    
    // Create smooth gradient mask first
    let radialGradient = CIFilter.radialGradient()
    radialGradient.center = CGPoint(x: faceCenterX, y: faceCenterY)
    radialGradient.radius0 = Float(faceRect.width * 0.1)
    radialGradient.radius1 = Float(faceRect.width * 0.4)
    radialGradient.color0 = CIColor(red: 1, green: 1, blue: 1)
    radialGradient.color1 = CIColor(red: 0, green: 0, blue: 0)
    
    guard let mask = radialGradient.outputImage?.cropped(to: image.extent) else { return image }
    
    // Apply localized pinch
    let pinchDistortion = CIFilter.pinchDistortion()
    pinchDistortion.inputImage = image
    pinchDistortion.center = CGPoint(x: faceCenterX, y: faceCenterY)
    // TODO: [AdjustmentDistortion] Adjust radius multiplier (0.3 = 30% of face width)
    pinchDistortion.radius = Float(faceRect.width * 0.3)
    
    // TODO: [AdjustmentDistortion] Adjust scale multiplier (1.8 = moderate effect)
    let pinchScale = (1.0 - scale) * 1.8
    pinchDistortion.scale = Float(pinchScale)
    
    guard let distorted = pinchDistortion.outputImage else { return image }
    
    // Blend with mask
    let blend = CIFilter.blendWithMask()
    blend.inputImage = distorted
    blend.backgroundImage = image
    blend.maskImage = mask
    
    return blend.outputImage ?? image
  }

  private func applyShoulderScaling(to image: CIImage, shoulderMask: CIImage, faceRect: CGRect, scale: CGFloat, originalSize: CGSize) -> CIImage {
    let resizedMask = shoulderMask.transformed(by: CGAffineTransform(
      scaleX: originalSize.width / shoulderMask.extent.width,
      y: originalSize.height / shoulderMask.extent.height
    ))

    // Create smooth gradient mask for shoulders
    // TODO: [AdjustmentDistortion] Adjust shoulder offset from face (0.5 = half face height below face)
    let shoulderY = faceRect.maxY + faceRect.height * 0.5
    
    let linearGradient = CIFilter.linearGradient()
    linearGradient.point0 = CGPoint(x: originalSize.width / 2, y: faceRect.maxY)
    linearGradient.point1 = CGPoint(x: originalSize.width / 2, y: shoulderY)
    linearGradient.color0 = CIColor(red: 0, green: 0, blue: 0)
    linearGradient.color1 = CIColor(red: 1, green: 1, blue: 1)
    
    guard let gradientMask = linearGradient.outputImage else { return image }
    
    // Combine person mask with gradient
    let multiplyFilter = CIFilter.multiplyCompositing()
    multiplyFilter.inputImage = resizedMask
    multiplyFilter.backgroundImage = gradientMask.cropped(to: CGRect(origin: .zero, size: originalSize))
    
    guard let shoulderMaskWithGradient = multiplyFilter.outputImage else { return image }

    // Apply horizontal stretch using affine transform
    // Center the transform to avoid displacement
    let centerX = image.extent.midX
    let transform = CGAffineTransform(translationX: -centerX, y: 0)
      .scaledBy(x: scale, y: 1.0)
      .translatedBy(x: centerX, y: 0)
    
    let stretchedImage = image.transformed(by: transform)
      .cropped(to: image.extent)

    let blendFilter = CIFilter.blendWithMask()
    blendFilter.inputImage = stretchedImage
    blendFilter.backgroundImage = image
    blendFilter.maskImage = shoulderMaskWithGradient

    return blendFilter.outputImage?.cropped(to: image.extent) ?? image
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
