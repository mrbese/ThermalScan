import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]
    @State private var showingScan = false
    @State private var showingManualEntry = false
    @State private var roomToDelete: Room?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if rooms.isEmpty {
                    emptyState
                } else {
                    roomList
                }
            }
            .navigationTitle("ThermalScan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingScan = true }) {
                            Label("Scan Room (LiDAR)", systemImage: "camera.viewfinder")
                        }
                        Button(action: { showingManualEntry = true }) {
                            Label("Enter Manually", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showingScan) {
                ScanView()
            }
            .sheet(isPresented: $showingManualEntry) {
                DetailsView(squareFootage: nil)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 64))
                    .foregroundStyle(Constants.accentColor)

                VStack(spacing: 8) {
                    Text("ThermalScan")
                        .font(.largeTitle.bold())

                    Text("Know your home's energy needs\nin 60 seconds")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 12) {
                if RoomCaptureService.isLiDARAvailable {
                    primaryButton(
                        title: "Start Scan",
                        subtitle: "Uses iPhone LiDAR",
                        icon: "camera.viewfinder"
                    ) {
                        showingScan = true
                    }
                }

                secondaryButton(
                    title: "Enter Manually",
                    icon: "pencil"
                ) {
                    showingManualEntry = true
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Room list

    private var roomList: some View {
        List {
            Section {
                ForEach(rooms) { room in
                    NavigationLink {
                        ResultsView(room: room)
                    } label: {
                        RoomRowView(room: room)
                    }
                }
                .onDelete(perform: deleteRooms)
            } header: {
                Text("Saved Rooms")
                    .textCase(nil)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(.bottom, 4)
            }

            Section {
                if RoomCaptureService.isLiDARAvailable {
                    Button(action: { showingScan = true }) {
                        Label("Scan New Room", systemImage: "camera.viewfinder")
                            .foregroundStyle(Constants.accentColor)
                    }
                }
                Button(action: { showingManualEntry = true }) {
                    Label("Enter Manually", systemImage: "pencil")
                        .foregroundStyle(Constants.accentColor)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func deleteRooms(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rooms[index])
        }
    }

    private func primaryButton(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).fontWeight(.semibold)
                    Text(subtitle).font(.caption).opacity(0.8)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Constants.accentColor, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func secondaryButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(title).fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .opacity(0.7)
            }
            .foregroundStyle(Constants.accentColor)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Constants.accentColor, lineWidth: 1.5)
            )
        }
    }
}

private struct RoomRowView: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(room.name.isEmpty ? "Unnamed Room" : room.name)
                    .font(.headline)
                Spacer()
                Text("\(Int(room.calculatedTonnage * 10) / 10) ton")
                    .font(.subheadline.bold())
                    .foregroundStyle(Constants.accentColor)
            }
            HStack(spacing: 12) {
                Label("\(Int(room.squareFootage)) sq ft", systemImage: "square.dashed")
                Label(room.climateZoneEnum.rawValue, systemImage: "thermometer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

