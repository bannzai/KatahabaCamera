import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@MainActor
class ImageWarper {
  private let context = CIContext()

  func warpImage(_ image: UIImage, faceRect: CGRect, shoulderMask: CIImage, intensity: CGFloat, faceRange: CGFloat = 0.35) -> UIImage? {
    guard let inputCIImage = CIImage(image: image) else { return nil }

    // TODO: [AdjustmentDistortion] Base scale values (face: 0.65 = 35% smaller, shoulder: 1.25 = 25% wider)
    let baseFaceScale: CGFloat = 0.65
    let baseShoulderScale: CGFloat = 1.25

    let faceScale = 1.0 - (1.0 - baseFaceScale) * intensity
    let shoulderScale = 1.0 + (baseShoulderScale - 1.0) * intensity

    let scaledFaceImage = applyFaceScaling(to: inputCIImage, faceRect: faceRect, scale: faceScale, range: faceRange)

    // TODO: [AdjustmentDistortion] Enable/disable shoulder effect
    let enableShoulderEffect = false
    
    let finalImage: CIImage
    if enableShoulderEffect {
      finalImage = applyShoulderScaling(
        to: scaledFaceImage,
        shoulderMask: shoulderMask,
        faceRect: faceRect,
        scale: shoulderScale,
        originalSize: image.size
      )
    } else {
      finalImage = scaledFaceImage
    }

    // Ensure the output image has the same extent as the input
    let outputExtent = inputCIImage.extent
    guard let outputCGImage = context.createCGImage(finalImage, from: outputExtent) else {
      return nil
    }

    return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
  }

  private func applyFaceScaling(to image: CIImage, faceRect: CGRect, scale: CGFloat, range: CGFloat) -> CIImage {
    let faceCenterX = faceRect.midX
    let faceCenterY = faceRect.midY
    
    print("Applying face scaling - center: (\(faceCenterX), \(faceCenterY)), scale: \(scale), range: \(range)")
    
    // Use a combination of scaling and masking for better face shrinking
    let clampedRange = max(0.2, min(0.6, range))
    let effectRadius = faceRect.width * clampedRange
    
    // Create a smaller version of the entire image
    let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
    let scaledImage = image.transformed(by: scaleTransform)
    
    // Calculate offset to center the scaled face at the original position
    let offsetX = faceCenterX * (1 - scale)
    let offsetY = faceCenterY * (1 - scale)
    let translationTransform = CGAffineTransform(translationX: offsetX, y: offsetY)
    let positionedScaledImage = scaledImage.transformed(by: translationTransform)
    
    // Create a radial gradient mask for smooth blending
    let radialGradient = CIFilter.radialGradient()
    radialGradient.center = CGPoint(x: faceCenterX, y: faceCenterY)
    radialGradient.radius0 = Float(effectRadius * 0.5)
    radialGradient.radius1 = Float(effectRadius)
    radialGradient.color0 = CIColor.white
    radialGradient.color1 = CIColor.black
    
    guard let gradientMask = radialGradient.outputImage?.cropped(to: image.extent) else {
      // Fallback to bump distortion
      let bump = CIFilter.bumpDistortion()
      bump.inputImage = image
      bump.center = CGPoint(x: faceCenterX, y: faceCenterY)
      bump.radius = Float(effectRadius)
      bump.scale = Float(scale - 1.0)
      return bump.outputImage ?? image
    }
    
    // Blend the scaled image with the original using the gradient mask
    let blendFilter = CIFilter.blendWithMask()
    blendFilter.inputImage = positionedScaledImage.cropped(to: image.extent)
    blendFilter.backgroundImage = image
    blendFilter.maskImage = gradientMask
    
    return blendFilter.outputImage ?? image
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
    let centerY = image.extent.midY
    
    // Create a transform that scales from the center
    let transform = CGAffineTransform(translationX: -centerX, y: -centerY)
      .scaledBy(x: scale, y: 1.0)
      .translatedBy(x: centerX / scale, y: centerY)
    
    // Ensure the transformed image fits within the original bounds
    let originalExtent = image.extent
    let stretchedImage = image.transformed(by: transform)
    
    // Calculate the cropping rect to center the stretched image
    let stretchedExtent = stretchedImage.extent
    let xOffset = (stretchedExtent.width - originalExtent.width) / 2
    let cropRect = CGRect(
      x: stretchedExtent.origin.x + xOffset,
      y: stretchedExtent.origin.y,
      width: originalExtent.width,
      height: originalExtent.height
    )
    
    let croppedStretchedImage = stretchedImage.cropped(to: cropRect)
      .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))

    let blendFilter = CIFilter.blendWithMask()
    blendFilter.inputImage = croppedStretchedImage
    blendFilter.backgroundImage = image
    blendFilter.maskImage = shoulderMaskWithGradient

    return blendFilter.outputImage?.cropped(to: originalExtent) ?? image
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
