import SwiftUI
@preconcurrency import AVFoundation
import PhotosUI
import UIKit

struct BillUploadView: View {
    let onResult: (ParsedBillResult, UIImage) -> Void
    let onManual: () -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = BillCameraService()
    @State private var capturedImage: UIImage?
    @State private var parsedResult: ParsedBillResult?
    @State private var isProcessing = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            BillCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide
                Text("Point at your utility bill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                if isProcessing {
                    ProgressView("Parsing bill...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                } else if let result = parsedResult, let image = capturedImage {
                    parsedResultCard(result: result, image: image)
                }

                Spacer()

                // Buttons
                if !isProcessing && parsedResult == nil {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }

                        Spacer()

                        Button(action: captureAndParse) {
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

                        // Photo library + manual options
                        Menu {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Photo Library", systemImage: "photo.on.rectangle")
                            }
                            Button(action: {
                                dismiss()
                                onManual()
                            }) {
                                Label("Enter Manually", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                    isProcessing = true
                    let result = await BillParsingService.parseBill(from: image)
                    parsedResult = result
                    isProcessing = false
                } else {
                    errorMessage = "Could not load the selected photo. Please try another image."
                    showError = true
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func parsedResultCard(result: ParsedBillResult, image: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("Bill Data")
                .font(.headline)
                .foregroundStyle(.white)

            if let name = result.utilityName {
                infoRow(label: "Utility", value: name)
            }

            if let kwh = result.totalKWh {
                infoRow(label: "Usage", value: "\(Int(kwh)) kWh")
            }

            if let cost = result.totalCost {
                infoRow(label: "Total", value: String(format: "$%.2f", cost))
            }

            if let rate = result.ratePerKWh {
                infoRow(label: "Rate", value: String(format: "$%.3f/kWh", rate))
            }

            if let start = result.billingPeriodStart {
                let formatter = DateFormatter()
                let _ = (formatter.dateStyle = .medium)
                let endStr = result.billingPeriodEnd.map { formatter.string(from: $0) } ?? "—"
                infoRow(label: "Period", value: "\(formatter.string(from: start)) – \(endStr)")
            }

            if result.totalKWh == nil && result.totalCost == nil {
                Text("Could not parse bill details.\nYou can edit values in the next step.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Use This") {
                    onResult(result, image)
                    dismiss()
                }
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Constants.accentColor, in: Capsule())

                Button("Retake") {
                    capturedImage = nil
                    parsedResult = nil
                    selectedPhoto = nil
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .font(.subheadline)
        .padding(20)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 20)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
        }
    }

    private func captureAndParse() {
        camera.capturePhoto { image in
            guard let image else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = "Failed to capture photo. Please try again."
                showError = true
                return
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            capturedImage = image
            isProcessing = true
            Task {
                let result = await BillParsingService.parseBill(from: image)
                parsedResult = result
                isProcessing = false
            }
        }
    }
}

// MARK: - Camera Service

@MainActor
private class BillCameraService: NSObject, ObservableObject {
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
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
}

extension BillCameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.completion?(nil) }
            return
        }
        Task { @MainActor in self.completion?(image) }
    }
}

private struct BillCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
