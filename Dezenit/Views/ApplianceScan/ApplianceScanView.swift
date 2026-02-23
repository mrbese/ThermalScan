import SwiftUI
@preconcurrency import AVFoundation
import UIKit

struct ApplianceScanView: View {
    let onClassified: (ClassificationResult, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = ApplianceCameraService()
    @State private var capturedImage: UIImage?
    @State private var classificationResults: [ClassificationResult] = []
    @State private var isClassifying = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide text
                Text("Point camera at an appliance")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                if isClassifying {
                    ProgressView("Identifying...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                } else if !classificationResults.isEmpty, let image = capturedImage {
                    // Results chips
                    VStack(spacing: 12) {
                        Text("What is this?")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(classificationResults) { result in
                            Button {
                                onClassified(result, image)
                                dismiss()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: result.category.icon)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.category.rawValue)
                                            .font(.subheadline.bold())
                                        if result.confidence > 0 {
                                            Text("\(Int(result.confidence * 100))% confidence")
                                                .font(.caption)
                                                .opacity(0.7)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Button("Retake") {
                            capturedImage = nil
                            classificationResults = []
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Capture button (hidden when results showing)
                if classificationResults.isEmpty && !isClassifying {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }

                        Spacer()

                        Button(action: captureAndClassify) {
                            Circle()
                                .fill(.white)
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.5), lineWidth: 3)
                                        .frame(width: 80, height: 80)
                                )
                        }
                        .accessibilityLabel("Capture photo")

                        Spacer()

                        // Balance spacer
                        Text("Cancel")
                            .foregroundStyle(.clear)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func captureAndClassify() {
        camera.capturePhoto { image in
            guard let image else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "Failed to capture photo. Please try again."
                showError = true
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            capturedImage = image
            isClassifying = true

            Task {
                let results = await ApplianceClassificationService.classify(image: image, topK: 3)
                if results.isEmpty {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = "Could not identify this appliance. Try a different angle or add it manually."
                    showError = true
                    isClassifying = false
                } else {
                    classificationResults = results
                    isClassifying = false
                }
            }
        }
    }
}

// MARK: - Camera Service (reusable pattern)

@MainActor
private class ApplianceCameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    func start() {
        guard !session.isRunning else { return }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }

        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stop() {
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension ApplianceCameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.completion?(nil) }
            return
        }
        Task { @MainActor in self.completion?(image) }
    }
}

// MARK: - Camera Preview

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}
