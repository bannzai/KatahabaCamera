import SwiftUI

struct EditingView: View {
  @ObservedObject var viewModel: CameraViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()

        if let image = viewModel.processedImage {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
