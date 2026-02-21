import SwiftUI
import RoomPlan

struct ScanView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = RoomCaptureService()
    @State private var detectedSqFt: Double = 0
    @State private var detectedWindows: [WindowInfo] = []
    @State private var showingDetails = false
    @State private var scanStarted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    switch service.state {
                    case .unavailable:
                        unavailablePlaceholder
                    case .idle:
                        idleOverlay
                    case .scanning:
                        scanningView
                    case .processing:
                        processingView
                    case .completed(let sqFt, let windows):
                        completedCard(sqFt: sqFt, windows: windows)
                    case .failed(let error):
                        errorView(error: error)
                    }
                }
            }
            .navigationTitle("Scan Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDetails) {
                DetailsView(squareFootage: detectedSqFt, scannedWindows: detectedWindows)
            }
        }
    }

    // MARK: - States

    private var idleOverlay: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(Constants.accentColor)
            VStack(spacing: 8) {
                Text("Ready to Scan")
                    .font(.title2.bold())
                Text("Walk slowly around the room.\nKeep your iPhone upright.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Button(action: {
                service.startSession()
                scanStarted = true
            }) {
                Text("Start Scan")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var scanningView: some View {
        ZStack(alignment: .bottom) {
            if let view = service.captureView {
                RoomCaptureViewRepresentable(captureView: view)
                    .ignoresSafeArea()
            }

            VStack(spacing: 16) {
                HStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                    Text("Scanning…")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.black.opacity(0.5), in: Capsule())

                Button(action: { service.stopSession() }) {
                    Text("Finish Scan")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private var processingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing scan…")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func completedCard(sqFt: Double, windows: [WindowInfo]) -> some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Constants.accentColor)

                Text("Scan Complete")
                    .font(.title2.bold())

                VStack(spacing: 6) {
                    Text("Detected floor area")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(sqFt)) sq ft")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Constants.accentColor)
                }

                if !windows.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "window.casement")
                        Text("\(windows.count) window\(windows.count == 1 ? "" : "s") detected")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }

            Text("Floor area and windows pre-filled. Verify directions in next step.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: {
                detectedSqFt = sqFt
                detectedWindows = windows
                showingDetails = true
            }) {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Button(action: { service.reset() }) {
                Text("Scan Again")
                    .foregroundStyle(Constants.accentColor)
            }

            Spacer()
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Scan Failed")
                .font(.title3.bold())
            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button(action: { service.reset() }) {
                Text("Try Again")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
        }
    }

    private var unavailablePlaceholder: some View {
        VStack(spacing: 24) {
            Image(systemName: "iphone.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("LiDAR Not Available")
                    .font(.title3.bold())
                Text("RoomPlan requires an iPhone 12 Pro or later with LiDAR scanner.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            Button(action: { dismiss() }) {
                Text("Enter Measurements Manually")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - UIViewRepresentable wrapper

private struct RoomCaptureViewRepresentable: UIViewRepresentable {
    let captureView: RoomCaptureView

    func makeUIView(context: Context) -> RoomCaptureView { captureView }
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}
}
