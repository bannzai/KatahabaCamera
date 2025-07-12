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
    
    // Create a crop region that's larger than the face to have room for distortion
    let cropPadding: CGFloat = 1.5
    let cropRect = CGRect(
      x: faceRect.origin.x - faceRect.width * (cropPadding - 1.0) / 2.0,
      y: faceRect.origin.y - faceRect.height * (cropPadding - 1.0) / 2.0,
      width: faceRect.width * cropPadding,
      height: faceRect.height * cropPadding
    ).intersection(image.extent)
    
    // Crop the face area
    let croppedFaceImage = image.cropped(to: cropRect)
    
    // Apply pinch distortion to the cropped area only
    let pinchDistortion = CIFilter.pinchDistortion()
    pinchDistortion.inputImage = croppedFaceImage
    pinchDistortion.center = CGPoint(x: faceCenterX, y: faceCenterY)
    // TODO: [AdjustmentDistortion] Adjust radius multiplier (0.4 = 40% of face width)
    pinchDistortion.radius = Float(faceRect.width * 0.4)
    
    // TODO: [AdjustmentDistortion] Adjust scale multiplier (2.5 = moderate, 3.5 = strong effect)
    let pinchScale = (1.0 - scale) * 2.5
    pinchDistortion.scale = Float(pinchScale)
    
    print("Pinch distortion - radius: \(pinchDistortion.radius), scale: \(pinchScale)")
    
    guard let distortedCrop = pinchDistortion.outputImage else { return image }
    
    // Create elliptical gradient mask for smooth blending
    let radialGradient = CIFilter.radialGradient()
    radialGradient.center = CGPoint(x: faceCenterX, y: faceCenterY)
    // TODO: [AdjustmentDistortion] Adjust gradient inner radius (0.2 = 20% of face width)
    radialGradient.radius0 = Float(faceRect.width * 0.2)
    // TODO: [AdjustmentDistortion] Adjust gradient outer radius (0.5 = 50% of face width)
    radialGradient.radius1 = Float(faceRect.width * 0.5)
    radialGradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
    radialGradient.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
    
    guard let gradientMask = radialGradient.outputImage?.cropped(to: cropRect) else { return image }
    
    // Blend the distorted crop with the original crop using the gradient
    let blendCrop = CIFilter.blendWithMask()
    blendCrop.inputImage = distortedCrop
    blendCrop.backgroundImage = croppedFaceImage
    blendCrop.maskImage = gradientMask
    
    guard let blendedCrop = blendCrop.outputImage else { return image }
    
    // Composite the blended crop back onto the original image
    let compositor = CIFilter.sourceOverCompositing()
    compositor.inputImage = blendedCrop
    compositor.backgroundImage = image
    
    return compositor.outputImage ?? image
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
