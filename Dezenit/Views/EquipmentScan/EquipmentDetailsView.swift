import SwiftUI
import SwiftData
import UIKit

struct EquipmentDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let home: Home
    var allowedTypes: [EquipmentType]? = nil
    var onComplete: (() -> Void)? = nil

    @State private var equipmentType: EquipmentType = .centralAC
    @State private var manufacturer: String = ""
    @State private var modelNumber: String = ""
    @State private var ageRange: AgeRange = .years5to10
    @State private var manualEfficiency: String = ""
    @State private var notes: String = ""
    @State private var capturedImage: UIImage?
    @State private var ocrResult: OCRResult?
    @State private var showingCamera = false
    @State private var showingResult = false
    @State private var savedEquipment: Equipment?
    @State private var isProcessingOCR = false

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                photoSection
                detailsSection
                ageSection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEquipment() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Constants.accentColor)
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                EquipmentCameraView(equipmentType: equipmentType) { image in
                    showingCamera = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        capturedImage = image
                        processOCR(image: image)
                    }
                }
            }
            .navigationDestination(isPresented: $showingResult) {
                if let eq = savedEquipment {
                    EquipmentResultView(equipment: eq, home: home, onComplete: onComplete ?? { dismiss() })
                }
            }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("Equipment Type") {
            Picker("Type", selection: $equipmentType) {
                ForEach(allowedTypes ?? Array(EquipmentType.allCases)) { type in
                    Label(type.rawValue, systemImage: type.icon).tag(type)
                }
            }
            .pickerStyle(.navigationLink)
        }
        .onAppear {
            if let first = allowedTypes?.first, !allowedTypes!.contains(equipmentType) {
                equipmentType = first
            }
        }
    }

    private var photoSection: some View {
        Section {
            if let image = capturedImage {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if isProcessingOCR {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Reading label...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if let ocr = ocrResult, ocr.manufacturer != nil || ocr.efficiencyValue != nil {
                        Label("Label data detected and pre-filled below", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Button("Retake Photo") {
                        showingCamera = true
                    }
                    .font(.caption)
                }
            } else {
                Button(action: { showingCamera = true }) {
                    Label("Photograph Equipment Label", systemImage: "camera.fill")
                        .foregroundStyle(Constants.accentColor)
                }

                Text("Optional. Take a photo of the rating plate or EnergyGuide label for automatic data extraction.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Photo (Optional)")
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Manufacturer (optional)", text: $manufacturer)
            TextField("Model Number (optional)", text: $modelNumber)

            HStack {
                Text("Efficiency (\(equipmentType.efficiencyUnit))")
                Spacer()
                TextField("auto", text: $manualEfficiency)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
            }

            if manualEfficiency.isEmpty {
                let spec = EfficiencyDatabase.lookup(type: equipmentType, age: ageRange)
                Text("Will estimate \(String(format: "%.1f", spec.estimated)) \(equipmentType.efficiencyUnit) based on age")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ageSection: some View {
        Section("Equipment Age") {
            Picker("Age", selection: $ageRange) {
                ForEach(AgeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextField("Any additional notes (optional)", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - OCR Processing

    private func processOCR(image: UIImage) {
        isProcessingOCR = true
        Task {
            let result = await OCRService.recognizeText(from: image)
            ocrResult = result
            if let mfr = result.manufacturer, manufacturer.isEmpty {
                manufacturer = mfr
            }
            if let model = result.modelNumber, modelNumber.isEmpty {
                modelNumber = model
            }
            if let value = result.efficiencyValue, manualEfficiency.isEmpty {
                manualEfficiency = String(format: "%.1f", value)
            }
            isProcessingOCR = false
        }
    }

    // MARK: - Save

    private func saveEquipment() {
        guard savedEquipment == nil else {
            showingResult = true
            return
        }
        let spec = EfficiencyDatabase.lookup(type: equipmentType, age: ageRange)
        let efficiency = Double(manualEfficiency) ?? spec.estimated

        let eq = Equipment(
            type: equipmentType,
            manufacturer: manufacturer.isEmpty ? nil : manufacturer,
            modelNumber: modelNumber.isEmpty ? nil : modelNumber,
            ageRange: ageRange,
            estimatedEfficiency: efficiency,
            currentCodeMinimum: spec.codeMinimum,
            bestInClass: spec.bestInClass,
            photoData: capturedImage?.jpegData(compressionQuality: 0.7),
            notes: notes.isEmpty ? nil : notes
        )

        eq.home = home
        modelContext.insert(eq)
        home.updatedAt = Date()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        savedEquipment = eq
        showingResult = true
    }
}
