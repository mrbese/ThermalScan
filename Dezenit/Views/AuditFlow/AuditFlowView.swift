import SwiftUI
import SwiftData
import UIKit

struct AuditFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var home: Home

    @State private var currentStep: AuditStep = .homeBasics
    @State private var audit: AuditProgress?

    // Sub-view presentation states
    @State private var showingScan = false
    @State private var showingApplianceScan = false
    @State private var showingLightingScan = false
    @State private var showingBillScan = false

    // Camera → details hand-off
    @State private var showingApplianceDetails = false
    @State private var appliancePrefill: (ApplianceCategory, UIImage)?
    @State private var showingLightingDetails = false
    @State private var lightingPrefill: (BulbOCRResult, UIImage)?
    @State private var showingBillDetails = false
    @State private var billPrefill: (ParsedBillResult, UIImage)?

    private let hvacTypes: [EquipmentType] = [.centralAC, .heatPump, .furnace, .windowUnit]
    private let waterTypes: [EquipmentType] = [.waterHeater, .waterHeaterTankless]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let audit {
                    AuditProgressBar(auditProgress: audit, currentStep: currentStep)
                }

                // Step content
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.easeInOut(duration: 0.25), value: currentStep)

                // Bottom buttons (hidden for envelope — it has its own Save flow)
                if currentStep != .envelopeAssessment {
                    bottomBar
                }
            }
            .navigationTitle("Home Audit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { setupAudit() }
            // Camera sheets
            .sheet(isPresented: $showingScan) {
                ScanView(home: home)
            }
            .sheet(isPresented: $showingApplianceScan) {
                ApplianceScanView { result, image in
                    showingApplianceScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appliancePrefill = (result.category, image)
                        showingApplianceDetails = true
                    }
                }
            }
            .sheet(isPresented: $showingApplianceDetails) {
                if let (category, image) = appliancePrefill {
                    ApplianceDetailsView(
                        home: home,
                        prefilledCategory: category,
                        prefilledImage: image,
                        detectionMethod: "camera",
                        onComplete: { showingApplianceDetails = false }
                    )
                }
            }
            .sheet(isPresented: $showingLightingScan) {
                LightingCloseupView { result, image in
                    showingLightingScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        lightingPrefill = (result, image)
                        showingLightingDetails = true
                    }
                }
            }
            .sheet(isPresented: $showingLightingDetails) {
                if let (result, image) = lightingPrefill {
                    ApplianceDetailsView(
                        home: home,
                        prefilledCategory: result.bulbType ?? .ledBulb,
                        prefilledWattage: result.wattage,
                        prefilledImage: image,
                        detectionMethod: "ocr",
                        onComplete: { showingLightingDetails = false }
                    )
                }
            }
            .sheet(isPresented: $showingBillScan) {
                BillUploadView(
                    onResult: { result, image in
                        showingBillScan = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            billPrefill = (result, image)
                            showingBillDetails = true
                        }
                    },
                    onManual: {
                        showingBillScan = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showingBillDetails = true
                        }
                    }
                )
            }
            .sheet(isPresented: $showingBillDetails) {
                if let (result, image) = billPrefill {
                    BillDetailsView(
                        home: home,
                        prefilledResult: result,
                        prefilledImage: image,
                        onComplete: { showingBillDetails = false }
                    )
                } else {
                    BillDetailsView(home: home, onComplete: { showingBillDetails = false })
                }
            }
            // Equipment & room sheets (moved from bottom bar background)
            .sheet(isPresented: $showingEquipmentSheet) {
                EquipmentDetailsView(
                    home: home,
                    allowedTypes: pendingEquipmentTypes.isEmpty ? nil : pendingEquipmentTypes,
                    onComplete: { showingEquipmentSheet = false }
                )
            }
            .sheet(isPresented: $showingManualRoom) {
                DetailsView(squareFootage: nil, home: home, onComplete: {
                    showingManualRoom = false
                })
            }
            .sheet(isPresented: $showingApplianceManual) {
                ApplianceDetailsView(home: home, onComplete: { showingApplianceManual = false })
            }
            .sheet(isPresented: $showingLightingManual) {
                ApplianceDetailsView(
                    home: home,
                    prefilledCategory: .ledBulb,
                    onComplete: { showingLightingManual = false }
                )
            }
            .sheet(item: $windowEditRoom) { room in
                DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                    windowEditRoom = nil
                })
            }
            .sheet(item: $auditEditingRoom) { room in
                DetailsView(squareFootage: nil, home: home, existingRoom: room, onComplete: {
                    auditEditingRoom = nil
                })
            }
            .sheet(item: $scanningPlaceholderRoom) { room in
                ScanView(home: home, existingRoom: room)
            }
        }
    }

    // MARK: - Setup

    private func setupAudit() {
        if let existing = home.currentAudit {
            audit = existing
            currentStep = existing.currentStepEnum
        } else {
            let newAudit = AuditProgress(home: home)
            modelContext.insert(newAudit)
            audit = newAudit
            currentStep = .homeBasics
        }
        autoCompleteCurrentStep()
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .homeBasics:
            homeBasicsStep
        case .roomScanning:
            roomScanningStep
        case .hvacEquipment:
            hvacStep
        case .waterHeating:
            waterHeatingStep
        case .applianceInventory:
            applianceStep
        case .lightingAudit:
            lightingStep
        case .windowAssessment:
            windowStep
        case .envelopeAssessment:
            envelopeStep
        case .billUpload:
            billStep
        case .review:
            reviewStep
        }
    }

    // MARK: - Step 1: Home Basics

    private var homeBasicsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "house",
                    title: "Home Basics",
                    subtitle: "Review your home information."
                )

                VStack(spacing: 12) {
                    infoRow(label: "Name", value: home.name.isEmpty ? "Unnamed" : home.name)
                    if let address = home.address, !address.isEmpty {
                        infoRow(label: "Address", value: address)
                    }
                    infoRow(label: "Year Built", value: home.yearBuilt)
                    if home.computedTotalSqFt > 0 {
                        infoRow(label: "Square Footage", value: "\(Int(home.computedTotalSqFt)) sq ft")
                    }
                    infoRow(label: "Climate Zone", value: home.climateZone)
                }
                .padding(16)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
            }
            .padding(20)
        }
    }

    // MARK: - Step 2: Room Scanning

    private var roomScanningStep: some View {
        let completedRooms = home.rooms.filter { $0.squareFootage > 0 }
        let placeholderRooms = home.rooms.filter { $0.squareFootage == 0 }

        return ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "camera.viewfinder",
                    title: "Room Scanning",
                    subtitle: "Add rooms to your home. Use LiDAR scanning or enter manually."
                )

                if !completedRooms.isEmpty {
                    completedBadge("\(completedRooms.count) room\(completedRooms.count == 1 ? "" : "s") scanned")
                    ForEach(completedRooms) { room in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(room.squareFootage)) sq ft")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                if !placeholderRooms.isEmpty {
                    ForEach(placeholderRooms) { room in
                        VStack(spacing: 0) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("Needs details")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 8)

                            HStack(spacing: 8) {
                                if RoomCaptureService.isLiDARAvailable {
                                    Button {
                                        scanningPlaceholderRoom = room
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "camera.viewfinder")
                                            Text("Scan")
                                        }
                                        .font(.caption.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .foregroundStyle(Constants.accentColor)
                                        .background(Constants.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    auditEditingRoom = room
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text("Enter Manually")
                                    }
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(Constants.accentColor)
                                    .background(Constants.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 12)
                        }
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 12) {
                    if RoomCaptureService.isLiDARAvailable {
                        actionButton(icon: "camera.viewfinder", label: "Scan Room") {
                            showingScan = true
                        }
                    }
                    actionButton(icon: "pencil", label: "Enter Manually") {
                        showingManualRoom = true
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 3: HVAC Equipment

    private var hvacStep: some View {
        equipmentStep(
            icon: "snowflake",
            title: "HVAC Equipment",
            subtitle: "Log your heating and cooling systems — AC, heat pump, or furnace.",
            types: hvacTypes,
            filter: { hvacTypes.contains($0.typeEnum) }
        )
    }

    // MARK: - Step 4: Water Heating

    private var waterHeatingStep: some View {
        equipmentStep(
            icon: "drop.fill",
            title: "Water Heating",
            subtitle: "Log your water heater — tank or tankless.",
            types: waterTypes,
            filter: { waterTypes.contains($0.typeEnum) }
        )
    }

    private func equipmentStep(icon: String, title: String, subtitle: String, types: [EquipmentType], filter: (Equipment) -> Bool) -> some View {
        let matching = home.equipment.filter(filter)
        return ScrollView {
            VStack(spacing: 20) {
                stepHeader(icon: icon, title: title, subtitle: subtitle)

                if !matching.isEmpty {
                    completedBadge("\(matching.count) logged")
                    ForEach(matching) { eq in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(eq.typeEnum.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text("\(String(format: "%.1f", eq.estimatedEfficiency)) \(eq.typeEnum.efficiencyUnit)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                actionButton(icon: "plus.circle.fill", label: "Add \(title)") {
                    // Present EquipmentDetailsView with filtered types
                    showingEquipmentSheet = true
                    pendingEquipmentTypes = types
                }
            }
            .padding(20)
        }
    }

    @State private var showingEquipmentSheet = false
    @State private var pendingEquipmentTypes: [EquipmentType] = []
    @State private var showingManualRoom = false
    @State private var windowEditRoom: Room?
    @State private var auditEditingRoom: Room?
    @State private var scanningPlaceholderRoom: Room?


    // MARK: - Step 5: Appliance Inventory

    private var applianceStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "tv",
                    title: "Appliance Inventory",
                    subtitle: "Scan or add major appliances — refrigerator, dishwasher, washer, dryer, etc."
                )

                let nonLighting = home.appliances.filter { !$0.categoryEnum.isLighting }
                if !nonLighting.isEmpty {
                    completedBadge("\(nonLighting.count) appliance\(nonLighting.count == 1 ? "" : "s")")
                    ForEach(nonLighting) { appliance in
                        applianceRow(appliance)
                    }
                }

                HStack(spacing: 12) {
                    actionButton(icon: "camera.fill", label: "Scan") {
                        showingApplianceScan = true
                    }
                    actionButton(icon: "pencil", label: "Manual") {
                        showingApplianceManual = true
                    }
                }
            }
            .padding(20)
        }
    }

    @State private var showingApplianceManual = false

    // MARK: - Step 6: Lighting Audit

    private var lightingStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "lightbulb",
                    title: "Lighting Audit",
                    subtitle: "Scan bulb labels or add lighting fixtures to estimate energy use."
                )

                let lighting = home.appliances.filter { $0.categoryEnum.isLighting }
                if !lighting.isEmpty {
                    completedBadge("\(lighting.count) light\(lighting.count == 1 ? "" : "s")")
                    ForEach(lighting) { appliance in
                        applianceRow(appliance)
                    }
                }

                HStack(spacing: 12) {
                    actionButton(icon: "camera.fill", label: "Scan Label") {
                        showingLightingScan = true
                    }
                    actionButton(icon: "pencil", label: "Manual") {
                        showingLightingManual = true
                    }
                }
            }
            .padding(20)
        }
    }

    @State private var showingLightingManual = false

    // MARK: - Step 7: Window Assessment

    private var windowStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "window.casement",
                    title: "Window Assessment",
                    subtitle: "Assess window types and condition in each room."
                )

                let roomsWithWindows = home.rooms.filter { !$0.windows.isEmpty }
                if !roomsWithWindows.isEmpty {
                    completedBadge("\(roomsWithWindows.count) room\(roomsWithWindows.count == 1 ? "" : "s") assessed")
                }

                if home.rooms.isEmpty {
                    Text("Add rooms first (Step 2) to assess windows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    Text("Tap a room to edit its windows.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(home.rooms) { room in
                        Button {
                            windowEditRoom = room
                        } label: {
                            HStack {
                                Image(systemName: room.windows.isEmpty ? "circle" : "checkmark.circle.fill")
                                    .foregroundStyle(room.windows.isEmpty ? Color.secondary : Color.green)
                                Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(room.windows.count) window\(room.windows.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 8: Envelope Assessment

    private var envelopeStep: some View {
        EnvelopeAssessmentView(home: home, onComplete: {
            completeCurrentStep()
        })
    }

    // MARK: - Step 9: Bill Upload

    private var billStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                stepHeader(
                    icon: "doc.text",
                    title: "Bill Upload",
                    subtitle: "Upload utility bills to calibrate energy cost estimates."
                )

                if !home.energyBills.isEmpty {
                    completedBadge("\(home.energyBills.count) bill\(home.energyBills.count == 1 ? "" : "s") uploaded")
                    ForEach(home.energyBills) { bill in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(bill.utilityName ?? "Utility Bill")
                                .font(.subheadline)
                            Spacer()
                            Text("\(Int(bill.totalKWh)) kWh")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack(spacing: 12) {
                    actionButton(icon: "camera.fill", label: "Scan Bill") {
                        showingBillScan = true
                    }
                    actionButton(icon: "pencil", label: "Manual") {
                        billPrefill = nil
                        showingBillDetails = true
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Step 10: Review

    private var reviewStep: some View {
        VStack(spacing: 20) {
            stepHeader(
                icon: "checkmark.seal",
                title: "Review",
                subtitle: "Your audit is complete! View your full home energy report."
            )

            NavigationLink {
                HomeReportView(home: home)
                    .onAppear { completeCurrentStep() }
            } label: {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("View Full Report")
                            .fontWeight(.semibold)
                        Text("Assessment summary with upgrade plan")
                            .font(.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .padding()
                .background(Constants.secondaryColor, in: RoundedRectangle(cornerRadius: 14))
            }

            if let audit, audit.isComplete {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Constants.accentColor)
                    Text("Audit Complete!")
                        .font(.title2.bold())
                    Text("All 10 steps finished.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding(20)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentStep != .homeBasics {
                Button {
                    moveToPreviousStep()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.gray.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if currentStep == .review {
                Button {
                    audit?.markComplete(.review)
                    dismiss()
                } label: {
                    Text("Finish")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Constants.accentColor, in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    Button {
                        moveToNextStep()
                    } label: {
                        Text("Skip")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        completeCurrentStep()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(isCurrentStepSatisfied ? Constants.accentColor : Color.gray, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isCurrentStepSatisfied)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Navigation Logic

    private var isCurrentStepSatisfied: Bool {
        switch currentStep {
        case .homeBasics: return true
        case .roomScanning: return home.rooms.contains { $0.squareFootage > 0 }
        case .hvacEquipment: return home.equipment.contains { hvacTypes.contains($0.typeEnum) }
        case .waterHeating: return home.equipment.contains { waterTypes.contains($0.typeEnum) }
        case .applianceInventory: return home.appliances.contains { !$0.categoryEnum.isLighting }
        case .lightingAudit: return home.appliances.contains { $0.categoryEnum.isLighting }
        case .windowAssessment: return home.rooms.contains { !$0.windows.isEmpty }
        case .envelopeAssessment: return home.envelope != nil
        case .billUpload: return !home.energyBills.isEmpty
        case .review: return true
        }
    }

    private func autoCompleteCurrentStep() {
        // Auto-complete any steps that already have data
        for step in AuditStep.allCases where step != .review {
            if stepHasData(step) && !(audit?.isStepComplete(step) ?? true) {
                audit?.markComplete(step)
            }
        }
        // Skip to first incomplete step
        if let audit,
           let firstIncomplete = AuditStep.allCases.first(where: { !audit.isStepComplete($0) }) {
            currentStep = firstIncomplete
            audit.currentStep = firstIncomplete.rawValue
        }
    }

    private func stepHasData(_ step: AuditStep) -> Bool {
        switch step {
        case .homeBasics: return true
        case .roomScanning: return home.rooms.contains { $0.squareFootage > 0 }
        case .hvacEquipment: return home.equipment.contains { hvacTypes.contains($0.typeEnum) }
        case .waterHeating: return home.equipment.contains { waterTypes.contains($0.typeEnum) }
        case .applianceInventory: return home.appliances.contains { !$0.categoryEnum.isLighting }
        case .lightingAudit: return home.appliances.contains { $0.categoryEnum.isLighting }
        case .windowAssessment: return home.rooms.contains { !$0.windows.isEmpty }
        case .envelopeAssessment: return home.envelope != nil
        case .billUpload: return !home.energyBills.isEmpty
        case .review: return false
        }
    }

    private func completeCurrentStep() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        audit?.markComplete(currentStep)
        moveToNextStep()
    }

    private func moveToNextStep() {
        let allSteps = AuditStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx + 1 < allSteps.count else { return }
        currentStep = allSteps[idx + 1]
        audit?.currentStep = currentStep.rawValue
    }

    private func moveToPreviousStep() {
        let allSteps = AuditStep.allCases
        guard let idx = allSteps.firstIndex(of: currentStep),
              idx > 0 else { return }
        currentStep = allSteps[idx - 1]
        audit?.currentStep = currentStep.rawValue
    }

    // MARK: - Shared Components

    private func stepHeader(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(Constants.accentColor)
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func completedBadge(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Constants.statusSuccess)
            Text(text)
                .font(.subheadline.bold())
                .foregroundStyle(Constants.statusSuccess)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Constants.statusSuccess.opacity(0.1), in: Capsule())
    }

    private func actionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Constants.accentColor)
            .background(Constants.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
        }
    }

    private func applianceRow(_ appliance: Appliance) -> some View {
        HStack(spacing: 12) {
            Image(systemName: appliance.categoryEnum.icon)
                .foregroundStyle(Constants.accentColor)
                .frame(width: 24)
            Text(appliance.name)
                .font(.subheadline)
            Spacer()
            Text("\(Int(appliance.estimatedWattage))W")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}
