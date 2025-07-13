import SwiftUI

struct EditingView: View {
  @ObservedObject var viewModel: CameraViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var dragStartOffset: CGPoint = .zero

  var body: some View {
    NavigationView {
      ZStack {
        Color.black.ignoresSafeArea()

        if let image = viewModel.processedImage {
          GeometryReader { geometry in
            ZStack {
              Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                  // Calculate actual image display frame
                  let imageSize = image.size
                  let containerSize = geometry.size
                  let imageAspect = imageSize.width / imageSize.height
                  let containerAspect = containerSize.width / containerSize.height
                  
                  var displayWidth: CGFloat
                  var displayHeight: CGFloat
                  var offsetX: CGFloat = 0
                  var offsetY: CGFloat = 0
                  
                  if imageAspect > containerAspect {
                    displayWidth = containerSize.width
                    displayHeight = containerSize.width / imageAspect
                    offsetY = (containerSize.height - displayHeight) / 2
                  } else {
                    displayHeight = containerSize.height
                    displayWidth = containerSize.height * imageAspect
                    offsetX = (containerSize.width - displayWidth) / 2
                  }
                  
                  viewModel.updateDisplayInfo(
                    displaySize: CGSize(width: displayWidth, height: displayHeight),
                    displayOffset: CGPoint(x: offsetX, y: offsetY),
                    imageSize: imageSize,
                    containerSize: containerSize
                  )
                  // Ensure range indicator is positioned correctly on initial display
                  viewModel.updateRangeIndicator()
                }
                .onChange(of: geometry.size) { _ in
                  // Recalculate when container size changes
                  let imageSize = image.size
                  let containerSize = geometry.size
                  let imageAspect = imageSize.width / imageSize.height
                  let containerAspect = containerSize.width / containerSize.height
                  
                  var displayWidth: CGFloat
                  var displayHeight: CGFloat
                  var offsetX: CGFloat = 0
                  var offsetY: CGFloat = 0
                  
                  if imageAspect > containerAspect {
                    displayWidth = containerSize.width
                    displayHeight = containerSize.width / imageAspect
                    offsetY = (containerSize.height - displayHeight) / 2
                  } else {
                    displayHeight = containerSize.height
                    displayWidth = containerSize.height * imageAspect
                    offsetX = (containerSize.width - displayWidth) / 2
                  }
                  
                  viewModel.updateDisplayInfo(
                    displaySize: CGSize(width: displayWidth, height: displayHeight),
                    displayOffset: CGPoint(x: offsetX, y: offsetY),
                    imageSize: imageSize,
                    containerSize: containerSize
                  )
                }
              
              // Show face effect range circle
              if viewModel.showRangeIndicator {
                ZStack {
                  Circle()
                    .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: viewModel.rangeIndicatorSize, height: viewModel.rangeIndicatorSize)
                    .position(viewModel.rangeIndicatorPosition)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.rangeIndicatorSize)
                  
                  Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .frame(width: viewModel.rangeIndicatorSize * 0.6, height: viewModel.rangeIndicatorSize * 0.6)
                    .position(viewModel.rangeIndicatorPosition)
                  
                  // Center adjustment indicator
                  if viewModel.showCenterAdjustment {
                    Image(systemName: "plus.circle.fill")
                      .foregroundColor(.yellow)
                      .font(.system(size: 20))
                      .position(viewModel.rangeIndicatorPosition)
                      .gesture(
                        DragGesture()
                          .onChanged { value in
                            if dragStartOffset == .zero && viewModel.faceCenterOffset != .zero {
                              dragStartOffset = viewModel.faceCenterOffset
                            }
                            let scale = viewModel.displaySize.width / viewModel.imageSize.width
                            let deltaX = (value.location.x - value.startLocation.x) / scale
                            let deltaY = (value.location.y - value.startLocation.y) / scale
                            let newOffset = CGPoint(
                              x: dragStartOffset.x + deltaX,
                              y: dragStartOffset.y + deltaY
                            )
                            viewModel.updateFaceCenterOffset(newOffset)
                          }
                          .onEnded { value in
                            let scale = viewModel.displaySize.width / viewModel.imageSize.width
                            let deltaX = (value.location.x - value.startLocation.x) / scale
                            let deltaY = (value.location.y - value.startLocation.y) / scale
                            dragStartOffset = CGPoint(
                              x: dragStartOffset.x + deltaX,
                              y: dragStartOffset.y + deltaY
                            )
                          }
                      )
                  }
                }
              }
            }
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
              HStack {
                Text("Face Effect Range")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                if viewModel.faceCenterOffset != .zero {
                  Button(action: {
                    viewModel.updateFaceCenterOffset(.zero)
                    dragStartOffset = .zero
                  }) {
                    Image(systemName: "arrow.counterclockwise")
                      .font(.caption)
                      .foregroundColor(.white.opacity(0.8))
                  }
                }
                
                Button(action: {
                  viewModel.showCenterAdjustment.toggle()
                  viewModel.showRangeIndicator = viewModel.showCenterAdjustment
                }) {
                  HStack(spacing: 4) {
                    Image(systemName: "move.3d")
                      .font(.caption)
                    Text("Adjust Center")
                      .font(.caption2)
                  }
                  .foregroundColor(viewModel.showCenterAdjustment ? .yellow : .white.opacity(0.8))
                }
              }

              HStack {
                Image(systemName: "circle.dashed")
                  .foregroundColor(.white.opacity(0.6))
                  .font(.caption)

                Slider(value: $viewModel.faceEffectRange, in: 0.1...3.0, onEditingChanged: { editing in
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
                dragStartOffset = .zero
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
