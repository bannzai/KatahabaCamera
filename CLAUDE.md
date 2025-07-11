# KatahabaCamera – CLAUDE.md

> **Project nickname:** *肩幅カメラ (KatahabaCamera) — the tiny‑face, broad‑shoulder gag camera*

This document specifies **all functional, technical, and architectural details** Claude Code needs to implement to deliver an App Store‑ready iOS application.  
Please treat every unchecked item in the _Task‑list_ section as work to be done. Code samples use **Swift 5.10**, **Xcode 16** (beta OK), and **iOS 18 SDK**.

---

## 📸 1. Core Concept

* Live camera preview that **shrinks the user’s face width ~0.65×** while **expanding shoulder width ~1.25×** in real‑time (≥ 30 FPS on iPhone XR, 60 FPS on A14+).
* One‑tap shutter → still photo saved to Photos with effect baked in.
* Optionally hold‐to‐record 1080p@30 video with the same effect.
* “Normal/Exaggerated” slider (0.0–2.0) controlling intensity.

## 🎯 2. Functional Requirements

| ‑ | ID | Description |
|---|---|-------------|
| ✅ | **FR‑01** | Live preview with deform effect (front & back cameras). |
| ⬜ | **FR‑02** | Photo capture & save to user’s **Recents** album. |
| ⬜ | **FR‑03** | Video recording up to 30 s with audio. |
| ⬜ | **FR‑04** | UI slider to tune intensity in real time. |
| ⬜ | **FR‑05** | Flash toggle (rear) & timer (3 s). |
| ⬜ | **FR‑06** | “About this filter” sheet explaining it’s a joke app. |

## 📐 3. Technical Approach

1. **Vision / ARKit detection**  
   * Use `VNDetectFaceLandmarksRequest` (back) or `ARFaceTrackingConfiguration` (front) at 15 FPS.
   * Cache landmarks for 3 frames if face motion < 5 px.

2. **Mask ＆ Warp**  
   * Generate face bounding rect + radial fall‑off mask.  
   * Generate upper‑body mask via `VNGeneratePersonSegmentationRequest(level:.accurate)`.  
   * Feed both to a **MetalPetal** custom warp shader (preferred) or **CIWarpKernel** fallback.

3. **Image pipeline**

   ```text
   AVCaptureSession → CVPixelBuffer → MTLTexture
                        ↓ Vision
                      WarpParams
                        ↓
                  Warp Shader → MTKView preview
                                ↓
                        Photo / Video output
   ```

4. **Performance targets**

   | Device | Preview FPS |
   |--------|-------------|
   | iPhone XR | ≥ 30 |
   | iPhone 12 | ≥ 60 |

## 🛠 4. Development Stack

* **SwiftPM** packages only (no CocoaPods).  
* **MetalPetal** v3.x for GPU filters.  
* **SwiftUI** for all UI.  
* **Combine** (or `async/await`) for reactive stream.  
* iOS 16+ deployment target (ARFaceTracking requires A12 Bionic).

## 🗂 5. Suggested File Structure

```text
KatahabaCamera/
 ├─ App/
 │   ├─ KatahabaCameraApp.swift
 │   └─ Assets.xcassets
 ├─ Features/
 │   ├─ Camera/
 │   │   ├─ CameraView.swift
 │   │   ├─ CameraViewModel.swift
 │   │   └─ WarpShader.metal
 │   └─ About/
 ├─ Core/
 │   ├─ Vision/
 │   └─ Warp/
 ├─ Resources/
 └─ Tests/
```

## ✅ 6. Task‑list

> Mark each item with **`[x]`** when complete.

- [ ] Scaffold SwiftUI project & SwiftPM dependencies.
- [ ] Implement `CameraService` with `AVCaptureSession`.
- [ ] Integrate Vision face & person segmentation pipelines.
- [ ] Write MetalPetal warp filter (`KatahabaWarpFilter`).
- [ ] Build live preview with adjustable intensity.
- [ ] Photo capture pipeline with HEIC output.
- [ ] Video recording pipeline (H.264 @1080p/30).
- [ ] Settings sheet & localized strings (en, ja).
- [ ] App Store privacy manifest & icons.

## 📄 7. Acceptance Criteria

* All **FR‑xx** requirements met & pass on‑device tests.
* Memory usage \< 300 MB peak on iPhone XR during video.
* App Store _App Review 5.2.3_ compliance: “This is a humorous filter” clearly shown.
* Unit tests > 70 % code coverage for non‑UI logic.

---

## 📝 8. References

* Vision & MetalPetal sample: Apple **FaceDistortion** WWDC 2023.
* App Review Guideline 5.2 — *Intellectual Property; Derivative works*.

---

Cheers & happy coding!  
*Prepared 2025‑07‑12 (JST)*  
