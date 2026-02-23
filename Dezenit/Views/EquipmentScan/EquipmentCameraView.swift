import SwiftUI
@preconcurrency import AVFoundation
import UIKit

struct EquipmentCameraView: View {
    let equipmentType: EquipmentType
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = CameraService()
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide text
                Text(equipmentType.cameraPrompt)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                // Guide box overlay
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: geo.size.width * 0.75,
                               height: geo.size.height * 0.35)
                        .overlay(
                            Text("Align label here")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                Spacer()

                // Capture button
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                    }

                    Spacer()

                    Button(action: {
                        camera.capturePhoto { image in
                            if let image {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onCapture(image)
                            } else {
                                UINotificationFeedbackGenerator().notificationOccurred(.error)
                                errorMessage = "Failed to capture photo. Please try again."
                                showError = true
                            }
                        }
                    }) {
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

                    // Placeholder for layout balance
                    Text("Cancel")
                        .foregroundStyle(.clear)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.cameraUnavailable) { _, unavailable in
            if unavailable {
                errorMessage = "Camera is not available on this device."
                showError = true
            }
        }
        .alert("Camera Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
}

// MARK: - Camera Service

@MainActor
private class CameraService: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var completion: ((UIImage?) -> Void)?

    @Published var cameraUnavailable = false

    func start() {
        guard !session.isRunning else { return }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            cameraUnavailable = true
            return
        }

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

extension CameraService: AVCapturePhotoCaptureDelegate {
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

private struct CameraPreviewView: UIViewRepresentable {
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
