import SwiftUI
import SwiftData
import CoreLocation

struct DetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Input from scan (nil = manual entry)
    let scannedSqFt: Double?
    let windowsFromScan: Bool   // true when windows were auto-populated
    var home: Home? = nil

    // Form state
    @State private var roomName: String = ""
    @State private var squareFootage: String = ""
    @State private var ceilingHeight: CeilingHeightOption = .eight
    @State private var climateZone: ClimateZone = .moderate
    @State private var insulation: InsulationQuality = .average
    @State private var windows: [WindowInfo] = []
    @State private var showingResults = false
    @State private var savedRoom: Room?

    @StateObject private var locationDetector = ClimateZoneDetector()

    init(squareFootage: Double?, scannedWindows: [WindowInfo] = [], home: Home? = nil) {
        self.scannedSqFt = squareFootage
        self.windowsFromScan = !scannedWindows.isEmpty
        self.home = home
        if let sqFt = squareFootage {
            _squareFootage = State(initialValue: "\(Int(sqFt))")
        }
        _windows = State(initialValue: scannedWindows)
    }

    var body: some View {
        NavigationStack {
            Form {
                roomSection
                windowsSection
                environmentSection
            }
            .navigationTitle("Room Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Calculate") {
                        saveAndCalculate()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Constants.accentColor)
                    .disabled(!isFormValid)
                }
            }
            .navigationDestination(isPresented: $showingResults) {
                if let room = savedRoom {
                    ResultsView(room: room)
                }
            }
            .onAppear {
                locationDetector.detectClimateZone { zone in
                    if let zone { climateZone = zone }
                }
            }
        }
    }

    // MARK: - Form sections

    private var roomSection: some View {
        Section("Room Info") {
            TextField("Room Name (e.g. Living Room)", text: $roomName)

            HStack {
                Text("Floor Area")
                Spacer()
                TextField("sq ft", text: $squareFootage)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                Text("sq ft")
                    .foregroundStyle(.secondary)
            }

            if scannedSqFt != nil {
                HStack {
                    Image(systemName: "camera.viewfinder")
                        .foregroundStyle(Constants.accentColor)
                    Text("Detected by LiDAR scan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("Ceiling Height", selection: $ceilingHeight) {
                ForEach(CeilingHeightOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        }
    }

    private var windowsSection: some View {
        Section {
            ForEach($windows) { $window in
                WindowRowView(window: $window)
            }
            .onDelete { indexSet in
                windows.remove(atOffsets: indexSet)
            }

            Button(action: { windows.append(WindowInfo()) }) {
                Label("Add Window", systemImage: "plus.circle.fill")
                    .foregroundStyle(Constants.accentColor)
            }
        } header: {
            Text("Windows (\(windows.count))")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if windowsFromScan && !windows.isEmpty {
                    Label("Count and size detected by LiDAR. Verify directions.", systemImage: "camera.viewfinder")
                        .font(.caption)
                        .foregroundStyle(Constants.accentColor)
                }
                if !windows.isEmpty {
                    Text("Swipe left to remove a window.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var environmentSection: some View {
        Section("Environment") {
            Picker("Climate Zone", selection: $climateZone) {
                ForEach(ClimateZone.allCases) { zone in
                    VStack(alignment: .leading) {
                        Text(zone.rawValue)
                        Text(zone.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(zone)
                }
            }
            .pickerStyle(.navigationLink)

            Picker("Insulation Quality", selection: $insulation) {
                ForEach(InsulationQuality.allCases) { quality in
                    VStack(alignment: .leading) {
                        Text(quality.rawValue)
                        Text(quality.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(quality)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: - Logic

    private var isFormValid: Bool {
        guard let sqFt = Double(squareFootage), sqFt > 0 else { return false }
        return true
    }

    private func saveAndCalculate() {
        guard let sqFt = Double(squareFootage), sqFt > 0 else { return }

        let breakdown = EnergyCalculator.calculate(
            squareFootage: sqFt,
            ceilingHeight: ceilingHeight,
            climateZone: climateZone,
            insulation: insulation,
            windows: windows
        )

        let room = Room(
            name: roomName,
            squareFootage: sqFt,
            ceilingHeight: ceilingHeight.feet,
            climateZone: climateZone,
            insulation: insulation,
            windows: windows,
            calculatedBTU: breakdown.finalBTU,
            calculatedTonnage: breakdown.tonnage,
            scanWasUsed: scannedSqFt != nil
        )

        if let home {
            room.home = home
            home.updatedAt = Date()
        }
        modelContext.insert(room)
        savedRoom = room
        showingResults = true
    }
}

// MARK: - Window row

private struct WindowRowView: View {
    @Binding var window: WindowInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "window.casement")
                .foregroundStyle(Constants.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Picker("Direction", selection: $window.direction) {
                    ForEach(CardinalDirection.allCases) { dir in
                        Text(dir.fullName).tag(dir)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Picker("Size", selection: $window.size) {
                    ForEach(WindowSize.allCases) { size in
                        Text(size.description).tag(size)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .font(.caption)
            }

            Spacer()

            Text("+\(Int(window.heatGainBTU).formatted()) BTU")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

// MARK: - Location-based climate zone detection

@MainActor
final class ClimateZoneDetector: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((ClimateZone?) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func detectClimateZone(completion: @escaping (ClimateZone?) -> Void) {
        self.completion = completion
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            completion(nil)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        let lat = location.coordinate.latitude
        let zone: ClimateZone
        if lat < 32 { zone = .hot }
        else if lat < 40 { zone = .moderate }
        else { zone = .cold }
        Task { @MainActor in self.completion?(zone) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.completion?(nil) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else {
            Task { @MainActor in self.completion?(nil) }
        }
    }
}
