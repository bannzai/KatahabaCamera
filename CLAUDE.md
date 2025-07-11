# 肩幅カメラ – CLAUDE_MIN.md

**目的:** 撮影したら顔が超小顔になり肩幅が相対的に広く見えるカメラアプリ(クソアプリ)。顔をキュッと細く、肩を広げて撮影するだけのシンプルなジョークカメラ。動画や凝った機能は一切なし。

---

## 必須機能

1. **写真撮影**  
   * シャッターボタンで現在のプレビューを 1 枚撮影する、エフェクトを焼き込んで写真ライブラリに保存する。  
2. **写真編集・強度調整スライダー**  
   * 顔を自動検出して小顔化のための編集画面。ユーザーがエフェクトの誇張度を 0.0–1.0 で調整できる。
3. **保存・SNS シェア機能**
  * ライブラリに保存・SNSシェア機能をつける

これだけ。動画録画、ギャラリー表示、などは **やらない**。

---

## 技術メモ

* **Vision** `VNDetectFaceLandmarksRequest` で顔パーツ検出。  
* **Vision** `VNGeneratePersonSegmentationRequest` で肩領域マスク (精度=accurate)。  
* **MetalPetal** もしくは **CIWarpKernel** で X 方向にスケール処理。  
* **SwiftUI + AVFoundation** で UI とカメラプレビューを構築。  
* 依存ライブラリは **Swift Package Manager** のみ、外部 SDK 追加禁止。

---

## ディレクトリ (ざっくり)

```text
KatahabaCamera/
 ├─ App/
 ├─ Camera/
 │   ├─ CameraView.swift
 │   ├─ CameraService.swift
 │   └─ WarpShader.metal
 └─ Resources/
```

---

## TODO

- [ ] Xcode プロジェクト作成 (iOS 16+, SwiftUI テンプレート)。  
- [ ] `CameraService` で `AVCaptureSession` 構築。  
- [ ] Vision パイプライン → 顔 & 肩マスク抽出。  
- [ ] Metal/CI ワープシェーダ実装 (`faceScale:0.65`, `shoulderScale:1.25`)。  
- [ ] プレビュー表示 (`MTKView` or `CIContext` in `SwiftUI`)。  
- [ ] シャッターボタン → HEIC 写真保存。  
- [ ] SNSシェア機能
---

### その他
- デプロイメントターゲットは18.0にしよう
- Localizationについて。英語だけ対応しよう。だから、Textに渡すものは全部英文で良い

