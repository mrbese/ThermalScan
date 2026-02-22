import SwiftUI
import SwiftData
import UIKit

struct HomeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Home.updatedAt, order: .reverse) private var homes: [Home]
    @State private var showingAddHome = false
    @State private var homeToDelete: Home?
    @State private var showDeleteConfirmation = false
    @State private var navigateToSingleHome = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if homes.isEmpty {
                    emptyState
                } else if homes.count == 1 {
                    // Auto-navigate to the single home's dashboard
                    HomeDashboardView(home: homes[0])
                } else {
                    homeList
                }
            }
            .navigationTitle(homes.count == 1 ? (homes[0].name.isEmpty ? "Home" : homes[0].name) : "Dezenit")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !homes.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddHome = true }) {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("Add new home")
                    }
                }
            }
            .sheet(isPresented: $showingAddHome) {
                AddHomeSheet { home in
                    modelContext.insert(home)
                }
            }
            .confirmationDialog(
                "Delete Home",
                isPresented: $showDeleteConfirmation,
                presenting: homeToDelete
            ) { home in
                Button("Delete \"\(home.name.isEmpty ? "Unnamed Home" : home.name)\"", role: .destructive) {
                    modelContext.delete(home)
                }
            } message: { _ in
                Text("This will permanently delete all rooms and equipment data for this home.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Constants.accentColor)

                VStack(spacing: 8) {
                    Text("Dezenit")
                        .font(.largeTitle.bold())

                    Text("Your home energy audit,\nright in your pocket")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button(action: { showingAddHome = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Your Home").fontWeight(.semibold)
                        Text("Start your energy assessment").font(.caption).opacity(0.8)
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
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var homeList: some View {
        List {
            ForEach(homes) { home in
                NavigationLink {
                    HomeDashboardView(home: home)
                } label: {
                    HomeRowView(home: home)
                }
            }
            .onDelete(perform: deleteHomes)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteHomes(at offsets: IndexSet) {
        if let index = offsets.first {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            homeToDelete = homes[index]
            showDeleteConfirmation = true
        }
    }
}

// MARK: - Home Row

private struct HomeRowView: View {
    let home: Home

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(home.name.isEmpty ? "Unnamed Home" : home.name)
                    .font(.headline)
                Spacer()
                if !home.equipment.isEmpty {
                    let grade = GradingEngine.grade(for: home.equipment)
                    Text(grade.rawValue)
                        .font(.headline.bold())
                        .foregroundStyle(Constants.gradeColor(grade))
                        .accessibilityLabel("Efficiency grade \(grade.rawValue)")
                }
            }
            HStack(spacing: 12) {
                Label("\(home.rooms.count) room\(home.rooms.count == 1 ? "" : "s")", systemImage: "square.split.2x2")
                Label("\(home.equipment.count) equipment", systemImage: "wrench")
                if home.computedTotalSqFt > 0 {
                    Label("\(Int(home.computedTotalSqFt)) sq ft", systemImage: "square.dashed")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

}

// MARK: - Add Home Sheet

private struct AddHomeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var yearBuilt: YearRange = .y1990to2005
    @State private var sqFt = ""
    @State private var climateZone: ClimateZone = .moderate

    @StateObject private var locationDetector = ClimateZoneDetector()

    let onSave: (Home) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Home Info") {
                    TextField("Name (e.g. My House)", text: $name)
                    TextField("Address (optional)", text: $address)
                }

                Section("Details") {
                    Picker("Year Built", selection: $yearBuilt) {
                        ForEach(YearRange.allCases) { yr in
                            Text(yr.rawValue).tag(yr)
                        }
                    }

                    HStack {
                        Text("Total Sq Ft")
                        Spacer()
                        TextField("optional", text: $sqFt)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

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

                    if let city = locationDetector.detectedCity {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .font(.caption)
                                .foregroundStyle(Constants.accentColor)
                            Text("Based on your location (\(city))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if locationDetector.locationDenied {
                        Text("Location unavailable. Select your climate zone manually.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Climate zone affects heating/cooling load calculations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let home = Home(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            address: address.isEmpty ? nil : address,
                            yearBuilt: yearBuilt,
                            totalSqFt: Double(sqFt),
                            climateZone: climateZone
                        )
                        onSave(home)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            .onAppear {
                locationDetector.detectClimateZone { zone in
                    if let zone { climateZone = zone }
                }
            }
        }
    }
}
