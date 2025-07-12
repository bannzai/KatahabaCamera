import SwiftUI
import AVFoundation

struct CameraView: View {
  @StateObject private var viewModel = CameraViewModel()

  var body: some View {
    ZStack {
      if viewModel.permissionGranted {
        CameraPreviewView(cameraService: viewModel.cameraService)
          .ignoresSafeArea()

        VStack {
          Spacer()

          Button(action: {
            viewModel.capturePhoto()
          }) {
            Circle()
              .fill(Color.white)
              .frame(width: 70, height: 70)
              .overlay(
                Circle()
                  .stroke(Color.white.opacity(0.8), lineWidth: 2)
                  .frame(width: 80, height: 80)
              )
          }
          .padding(.bottom, 50)
        }
      } else {
        Text("Camera permission required")
          .font(.headline)
          .foregroundColor(.gray)
      }
    }
    .background(Color.black)
    .sheet(isPresented: $viewModel.isShowingEditView) {
      EditingView(viewModel: viewModel)
    }
    .onAppear {
      viewModel.cameraService.startSession()
    }
    .onDisappear {
      viewModel.cameraService.stopSession()
    }
  }
}

struct CameraPreviewView: UIViewRepresentable {
  let cameraService: CameraService

  class PreviewView: UIView {
    override func layoutSubviews() {
      super.layoutSubviews()
      layer.sublayers?.forEach { sublayer in
        sublayer.frame = bounds
      }
    }
  }

  func makeUIView(context: Context) -> UIView {
    let view = PreviewView()
    view.backgroundColor = .black
    
    let previewLayer = cameraService.makePreviewLayer()
    previewLayer.frame = view.bounds
    previewLayer.videoGravity = .resizeAspectFill
    view.layer.addSublayer(previewLayer)
    
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    // Layout is handled in PreviewView.layoutSubviews()
  }
}

#Preview {
  CameraView()
}
