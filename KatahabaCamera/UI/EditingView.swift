import SwiftUI

struct EditingView: View {
  @ObservedObject var viewModel: CameraViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()

        if let image = viewModel.processedImage {
          GeometryReader { geometry in
            Image(uiImage: image)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .overlay(
                // Show face effect range circle
                viewModel.showRangeIndicator ? 
                Circle()
                  .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                  .frame(width: viewModel.rangeIndicatorSize, height: viewModel.rangeIndicatorSize)
                  .position(viewModel.rangeIndicatorPosition)
                  .animation(.easeInOut(duration: 0.3), value: viewModel.rangeIndicatorSize)
                  .overlay(
                    Circle()
                      .stroke(Color.white.opacity(0.3), lineWidth: 1)
                      .frame(width: viewModel.rangeIndicatorSize * 0.6, height: viewModel.rangeIndicatorSize * 0.6)
                      .position(viewModel.rangeIndicatorPosition)
                  )
                : nil
              )
          }
        } else if let image = viewModel.capturedImage {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            )
        }

        VStack {
          Spacer()

          VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Effect Intensity")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

              HStack {
                Image(systemName: "person.fill")
                  .foregroundColor(.white.opacity(0.6))
                  .font(.caption)

                Slider(value: $viewModel.effectIntensity, in: 0...1) { _ in
                  viewModel.updateEffectIntensity(viewModel.effectIntensity)
                }
                .accentColor(.white)

                Image(systemName: "person.fill")
                  .foregroundColor(.white)
                  .font(.title3)
              }
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Face Effect Range")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

              HStack {
                Image(systemName: "circle.dashed")
                  .foregroundColor(.white.opacity(0.6))
                  .font(.caption)

                Slider(value: $viewModel.faceEffectRange, in: 0.2...0.6, onEditingChanged: { editing in
                  viewModel.showRangeIndicator = editing
                  if !editing {
                    viewModel.updateFaceEffectRange(viewModel.faceEffectRange)
                  }
                })
                .accentColor(.white)
                .onChange(of: viewModel.faceEffectRange) { newValue in
                  viewModel.updateRangeIndicator()
                }

                Image(systemName: "circle.dashed")
                  .foregroundColor(.white)
                  .font(.title3)
              }
            }
            .padding(.horizontal)

            HStack(spacing: 30) {
              Button(action: {
                viewModel.retake()
              }) {
                VStack {
                  Image(systemName: "arrow.uturn.backward")
                    .font(.title2)
                  Text("Retake")
                    .font(.caption)
                }
                .foregroundColor(.white)
              }

              Button(action: {
                viewModel.savePhoto()
              }) {
                VStack {
                  Image(systemName: "square.and.arrow.down")
                    .font(.title2)
                  Text("Save")
                    .font(.caption)
                }
                .foregroundColor(.white)
              }
              .disabled(viewModel.isSaving || viewModel.processedImage == nil)
              .opacity(viewModel.isSaving || viewModel.processedImage == nil ? 0.5 : 1.0)

              Button(action: {
                viewModel.sharePhoto()
              }) {
                VStack {
                  Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                  Text("Share")
                    .font(.caption)
                }
                .foregroundColor(.white)
              }
              .disabled(viewModel.processedImage == nil)
              .opacity(viewModel.processedImage == nil ? 0.5 : 1.0)
            }
            .padding(.bottom, 50)
          }
          .padding()
          .background(
            LinearGradient(
              gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.8)]),
              startPoint: .top,
              endPoint: .bottom
            )
          )
        }
      }
      .navigationBarHidden(true)
      .sheet(isPresented: $viewModel.showShareSheet) {
        if let image = viewModel.processedImage {
          ShareSheet(items: [image])
        }
      }
    }
  }
}

struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
