import SwiftUI
import AVFoundation

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            if viewModel.cameraService.permissionGranted {
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
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = cameraService.makePreviewLayer()
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

#Preview {
    CameraView()
}