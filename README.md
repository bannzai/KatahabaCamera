# KatahabaCamera

A joke camera app that makes your face smaller and shoulders wider in photos.

## Features

- **Face Detection**: Automatically detects faces using Vision framework
- **Shoulder Detection**: Detects shoulder area using person segmentation
- **Photo Effects**:
  - Face scaling: 0.65x (makes face appear smaller)
  - Shoulder scaling: 1.25x (makes shoulders appear wider)
  - Adjustable effect intensity: 0.0 to 1.0
- **Save & Share**: Save edited photos to library and share on social media

## Requirements

- iOS 18.0+
- Xcode 16.0+
- Front camera device

## Setup

1. Clone the repository
2. Open `KatahabaCamera.xcodeproj` in Xcode
3. Build and run on a physical device (camera required)

## Usage

1. **Grant Permissions**: Allow camera and photo library access when prompted
2. **Take Photo**: Tap the capture button to take a photo
3. **Adjust Effect**: Use the slider to adjust the effect intensity (0-100%)
4. **Save/Share**: 
   - Tap "Save" to save to photo library
   - Tap "Share" to share on social media
   - Tap "Retake" to take a new photo

## Technical Details

- **Architecture**: SwiftUI + AVFoundation
- **Face Detection**: `VNDetectFaceLandmarksRequest`
- **Shoulder Detection**: `VNGeneratePersonSegmentationRequest` (accurate quality)
- **Image Processing**: Core Image filters for warping effects
- **No External Dependencies**: Uses only native iOS frameworks