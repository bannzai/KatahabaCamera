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
    
    // Use a custom warp kernel for uniform face shrinking
    let clampedRange = max(0.2, min(0.6, range))
    let effectRadius = faceRect.width * clampedRange
    
    // Define the warp kernel with proper bounds checking
    let warpKernel = CIWarpKernel(source: """
      kernel vec2 uniformScale(vec2 centerPoint, float radius, float scale, vec4 extent) {
        vec2 currentPos = destCoord();
        vec2 delta = currentPos - centerPoint;
        float distance = length(delta);
        
        // Apply effect within radius
        if (distance < radius) {
          // Smooth falloff for natural transition
          float normalizedDistance = distance / radius;
          // Use Gaussian-like falloff for more natural shrinking
          float falloff = exp(-2.0 * normalizedDistance * normalizedDistance);
          
          // Interpolate scale with stronger effect in center
          float effectiveScale = mix(scale, 1.0, 1.0 - falloff);
          
          // Calculate source position - inverse mapping
          vec2 sourcePos;
          if (distance > 0.01) {
            vec2 direction = delta / distance;
            float newDistance = distance / effectiveScale;
            sourcePos = centerPoint + direction * newDistance;
          } else {
            sourcePos = currentPos;
          }
          
          // Clamp to image bounds to prevent sampling outside
          sourcePos.x = clamp(sourcePos.x, extent.x, extent.x + extent.z - 1.0);
          sourcePos.y = clamp(sourcePos.y, extent.y, extent.y + extent.w - 1.0);
          
          return sourcePos;
        }
        
        return currentPos;
      }
      """)
    
    guard let kernel = warpKernel else {
      print("Failed to create warp kernel")
      return image
    }
    

    let extent = image.extent
    let arguments = [
      CIVector(x: faceCenterX, y: faceCenterY),
      effectRadius,
      scale,
      CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
    ] as [Any]

    // Define the region of interest to include area that might be sampled
    let roiCallback: CIKernelROICallback = { _, rect in
      let expansion = effectRadius * 0.5
      return rect.insetBy(dx: -expansion, dy: -expansion)
    }
    
    return kernel.apply(
      extent: extent,
      roiCallback: roiCallback,
      image: image,
      arguments: arguments
    ) ?? image
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
