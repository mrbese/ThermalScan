import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var home: Home
    @State private var showingScan = false
    @State private var showingManualRoom = false
    @State private var showingEquipmentScan = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summaryCard
                roomsSection
                equipmentSection
                reportButton
            }
            .padding()
        }
        .navigationTitle(home.name.isEmpty ? "Home" : home.name)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingScan) {
            ScanView(home: home)
        }
        .sheet(isPresented: $showingManualRoom) {
            DetailsView(squareFootage: nil, home: home)
        }
        .sheet(isPresented: $showingEquipmentScan) {
            EquipmentDetailsView(home: home)
        }
    }

    // MARK: - Summary

    private var summaryCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    if !home.equipment.isEmpty {
                        let grade = GradingEngine.grade(for: home.equipment)
                        Text(grade.rawValue)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Efficiency")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("No Data")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    if home.computedTotalSqFt > 0 {
                        Label("\(Int(home.computedTotalSqFt)) sq ft", systemImage: "square.dashed")
                    }
                    Label("\(home.rooms.count) room\(home.rooms.count == 1 ? "" : "s")", systemImage: "square.split.2x2")
                    Label("\(home.equipment.count) equipment", systemImage: "wrench")
                    Label(home.climateZoneEnum.rawValue, systemImage: "thermometer")
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Rooms

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Rooms")
                    .font(.headline)
                Spacer()
                Menu {
                    if RoomCaptureService.isLiDARAvailable {
                        Button(action: { showingScan = true }) {
                            Label("Scan Room (LiDAR)", systemImage: "camera.viewfinder")
                        }
                    }
                    Button(action: { showingManualRoom = true }) {
                        Label("Enter Manually", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Constants.accentColor)
                }
            }

            if home.rooms.isEmpty {
                Text("No rooms scanned yet. Add a room to start your assessment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(home.rooms) { room in
                    NavigationLink {
                        ResultsView(room: room)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                                    .font(.subheadline.bold())
                                Text("\(Int(room.squareFootage)) sq ft")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(room.calculatedBTU).formatted()) BTU")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Constants.accentColor)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Equipment

    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Equipment")
                    .font(.headline)
                Spacer()
                Button(action: { showingEquipmentScan = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Constants.accentColor)
                }
            }

            if home.equipment.isEmpty {
                Text("No equipment logged yet. Add your HVAC, water heater, and more.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(home.equipment) { item in
                    NavigationLink {
                        EquipmentResultView(equipment: item, home: home)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.typeEnum.icon)
                                .font(.title3)
                                .foregroundStyle(Constants.accentColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.typeEnum.rawValue)
                                    .font(.subheadline.bold())
                                HStack(spacing: 4) {
                                    Text(item.ageRangeEnum.shortLabel)
                                    if let mfr = item.manufacturer {
                                        Text("| \(mfr)")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(String(format: "%.1f", item.estimatedEfficiency)) \(item.typeEnum.efficiencyUnit)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Constants.accentColor)
                        }
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Report

    private var reportButton: some View {
        Group {
            if !home.equipment.isEmpty || !home.rooms.isEmpty {
                NavigationLink {
                    HomeReportView(home: home)
                } label: {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Full Report").fontWeight(.semibold)
                            Text("Assessment summary with upgrade plan").font(.caption).opacity(0.8)
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
            }
        }
    }
}
