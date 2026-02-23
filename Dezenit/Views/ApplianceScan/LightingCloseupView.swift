import SwiftUI
@preconcurrency import AVFoundation
import UIKit

struct LightingCloseupView: View {
    let onResult: (BulbOCRResult, UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var camera = BulbCameraService()
    @State private var capturedImage: UIImage?
    @State private var ocrResult: BulbOCRResult?
    @State private var isProcessing = false
    @State private var showQuickSelect = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ZStack {
            BulbCameraPreview(session: camera.session)
                .ignoresSafeArea()

            VStack {
                // Guide
                Text("Hold close to the bulb label")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 60)

                Spacer()

                if isProcessing {
                    ProgressView("Reading label...")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                } else if let result = ocrResult, let image = capturedImage {
                    ocrResultCard(result: result, image: image)
                }

                Spacer()

                // Buttons
                if !isProcessing && ocrResult == nil {
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("Cancel")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                        }

                        Spacer()

                        Button(action: captureAndOCR) {
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

                        Button("Skip") {
                            showQuickSelect = true
                        }
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .alert("Capture Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showQuickSelect) {
            QuickWattageSelectView { wattage, bulbType in
                let result = BulbOCRResult(
                    wattage: wattage,
                    bulbType: bulbType,
                    rawText: "Manual selection"
                )
                onResult(result, UIImage())
                dismiss()
            }
        }
    }

    private func ocrResultCard(result: BulbOCRResult, image: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("Label Data")
                .font(.headline)
                .foregroundStyle(.white)

            if let wattage = result.wattage {
                HStack {
                    Text("Wattage")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(Int(wattage))W")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }

            if let lumens = result.lumens {
                HStack {
                    Text("Lumens")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(lumens) lm")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }

            if let temp = result.colorTemp {
                HStack {
                    Text("Color Temp")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text("\(temp)K")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
            }

            if let bulbType = result.bulbType {
                HStack {
                    Text("Type")
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(bulbType.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                }
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
                    ocrResult = nil
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

    private func captureAndOCR() {
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
                let result = await LightingOCRService.recognizeBulb(from: image)
                ocrResult = result
                isProcessing = false
            }
        }
    }
}

// MARK: - Quick Wattage Select (fallback)

private struct QuickWattageSelectView: View {
    let onSelect: (Double, ApplianceCategory) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ApplianceCategory = .ledBulb

    var body: some View {
        NavigationStack {
            List {
                Section("Bulb Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("LED").tag(ApplianceCategory.ledBulb)
                        Text("CFL").tag(ApplianceCategory.cflBulb)
                        Text("Incandescent").tag(ApplianceCategory.incandescentBulb)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Common Wattages") {
                    ForEach(wattages, id: \.self) { w in
                        Button {
                            onSelect(w, selectedType)
                            dismiss()
                        } label: {
                            HStack {
                                Text("\(Int(w))W")
                                    .font(.headline)
                                Spacer()
                                Text(equivalentDescription(watts: w, type: selectedType))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Wattage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var wattages: [Double] {
        switch selectedType {
        case .ledBulb: return Constants.CommonBulbWattages.led
        case .cflBulb: return Constants.CommonBulbWattages.cfl
        case .incandescentBulb: return Constants.CommonBulbWattages.incandescent
        default: return Constants.CommonBulbWattages.led
        }
    }

    private func equivalentDescription(watts: Double, type: ApplianceCategory) -> String {
        switch type {
        case .ledBulb:
            let equiv = Int(watts * 7) // rough LED to incandescent equiv
            return "~\(equiv)W incandescent equivalent"
        case .cflBulb:
            let equiv = Int(watts * 4.5)
            return "~\(equiv)W incandescent equivalent"
        default:
            return ""
        }
    }
}

// MARK: - Camera (same pattern)

@MainActor
private class BulbCameraService: NSObject, ObservableObject {
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

extension BulbCameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.completion?(nil) }
            return
        }
        Task { @MainActor in self.completion?(image) }
    }
}

private struct BulbCameraPreview: UIViewRepresentable {
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
