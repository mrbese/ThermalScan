import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import UIKit

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var didFinish = false

    // Data collected across steps
    @State private var homeName: String = ""
    @State private var address: String = ""
    @State private var homeType: HomeType = .house
    @State private var yearBuilt: YearRange = .y1990to2005
    @State private var sqFtText: String = ""
    @State private var climateZone: ClimateZone = .moderate
    @State private var roomCount: Int = 4
    @State private var bedroomCount: Int = 2

    @StateObject private var locationDetector = ClimateZoneDetector()
    @StateObject private var addressService = AddressSearchService()
    @FocusState private var addressFieldFocused: Bool

    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Progress dots (hidden on welcome)
            if currentStep > 0 {
                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= currentStep ? Constants.accentColor : Color.white.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            TabView(selection: $currentStep) {
                welcomeStep.tag(0)
                homeInfoStep.tag(1)
                homeTypeStep.tag(2)
                detailsStep.tag(3)
                roomsStep.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            // Bottom button
            bottomButton
        }
        .background(Color.black.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: didFinish)
    }

    // MARK: - Step 0: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            if let uiImage = UIImage(named: "AppIcon") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Constants.accentColor.opacity(0.4), radius: 20, y: 8)
            } else {
                Image(systemName: "house.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Constants.accentColor)
            }

            Text("Dezenit")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Your home energy audit,\nright in your pocket.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 1: Home Info (Name + Address)

    private var homeInfoStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Image(systemName: "house.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Constants.accentColor)

                Text("Your Home")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                VStack(spacing: 16) {
                    // Name (required)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Home Name")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))
                        TextField("e.g. My House", text: $homeName)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    // Address (optional) with autocomplete
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address (optional)")
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.6))

                        HStack(spacing: 0) {
                            TextField("e.g. 123 Main St, Austin, TX", text: $address)
                                .textFieldStyle(.plain)
                                .textContentType(.fullStreetAddress)
                                .focused($addressFieldFocused)
                                .padding(12)
                                .foregroundStyle(.white)
                                .onChange(of: address) { _, newValue in
                                    addressService.updateQuery(newValue)
                                    // Clear resolved state when user edits
                                    if newValue != addressService.selectedAddress {
                                        addressService.selectedCoordinate = nil
                                    }
                                }

                            // Use My Location button
                            Button {
                                Task {
                                    await addressService.useCurrentLocation()
                                    if let resolved = addressService.selectedAddress {
                                        address = resolved
                                    }
                                    addressFieldFocused = false
                                }
                            } label: {
                                Group {
                                    if addressService.isResolving {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "location.fill")
                                    }
                                }
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Constants.accentColor)
                                .padding(.trailing, 12)
                            }
                            .disabled(addressService.isResolving)
                        }
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                        // Suggestion list
                        if !addressService.suggestions.isEmpty && addressFieldFocused {
                            VStack(spacing: 0) {
                                ForEach(addressService.suggestions.prefix(4), id: \.self) { suggestion in
                                    Button {
                                        Task {
                                            await addressService.selectSuggestion(suggestion)
                                            if let resolved = addressService.selectedAddress {
                                                address = resolved
                                            }
                                            addressFieldFocused = false
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.title)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            if !suggestion.subtitle.isEmpty {
                                                Text(suggestion.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(.white.opacity(0.5))
                                                    .lineLimit(1)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                    }

                                    if suggestion != addressService.suggestions.prefix(4).last {
                                        Divider().background(Color.white.opacity(0.1))
                                    }
                                }
                            }
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }

                        // Map preview
                        if let coordinate = addressService.selectedCoordinate {
                            Map(initialPosition: .region(MKCoordinateRegion(
                                center: coordinate,
                                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                            ))) {
                                Marker("", coordinate: coordinate)
                                    .tint(Constants.accentColor)
                            }
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .allowsHitTesting(false)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                            Text("Helps determine your climate zone automatically")
                                .font(.caption)
                        }
                        .foregroundStyle(Constants.accentColor.opacity(0.8))
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 60)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Step 2: Home Type

    private var homeTypeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("What type of home?")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(spacing: 14) {
                ForEach(HomeType.allCases) { type in
                    let icon: String = switch type {
                    case .house: "house.fill"
                    case .townhouse: "building.2.fill"
                    case .apartment: "building.fill"
                    }

                    Button {
                        homeType = type
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 36)
                            Text(type.rawValue)
                                .font(.headline)
                            Spacer()
                            if homeType == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Constants.accentColor)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(homeType == type ? Constants.accentColor.opacity(0.2) : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(homeType == type ? Constants.accentColor : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 3: Details (Year Built, Sq Ft, Climate Zone)

    private var detailsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "pencil.and.list.clipboard")
                .font(.system(size: 48))
                .foregroundStyle(Constants.accentColor)

            Text("Home Details")
                .font(.title2.bold())
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                // Year Built
                VStack(alignment: .leading, spacing: 6) {
                    Text("Year Built")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    HStack {
                        ForEach(YearRange.allCases) { yr in
                            Button {
                                yearBuilt = yr
                            } label: {
                                Text(yr == .pre1970 ? "<1970" : yr == .y2016plus ? "2016+" : String(yr.rawValue.prefix(4)))
                                    .font(.caption2.bold())
                                    .foregroundStyle(yearBuilt == yr ? .white : .white.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        yearBuilt == yr ? Constants.accentColor : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Sq ft (optional)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total Sq Ft (optional)")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))
                    TextField("e.g. 1800", text: $sqFtText)
                        .textFieldStyle(.plain)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }

                // Climate Zone
                VStack(alignment: .leading, spacing: 8) {
                    Text("Climate Zone")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.6))

                    if let city = locationDetector.detectedCity {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Constants.accentColor)
                            Text("Detected: \(city)")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .font(.subheadline)
                    } else if locationDetector.locationDenied {
                        Text("Could not detect — select manually below.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    VStack(spacing: 8) {
                        ForEach(ClimateZone.allCases) { zone in
                            Button {
                                climateZone = zone
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(zone.rawValue)
                                            .font(.subheadline.bold())
                                        Text(zone.description)
                                            .font(.caption)
                                            .opacity(0.7)
                                    }
                                    Spacer()
                                    if climateZone == zone {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Constants.accentColor)
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(climateZone == zone ? Constants.accentColor.opacity(0.2) : Color.white.opacity(0.08))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(climateZone == zone ? Constants.accentColor : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("Affects heating & cooling load calculations.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .onAppear {
            triggerClimateDetection()
        }
    }

    // MARK: - Step 4: Rooms

    private var roomsStep: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "square.split.2x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(Constants.accentColor)

            Text("How many rooms?")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("We'll create placeholders you can scan or fill in later.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 20) {
                // Total rooms stepper
                HStack {
                    Text("Total Rooms")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 16) {
                        Button { if roomCount > 1 { roomCount -= 1 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(roomCount > 1 ? Constants.accentColor : .gray)
                        }
                        .disabled(roomCount <= 1)
                        Text("\(roomCount)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 36)
                        Button { if roomCount < 20 { roomCount += 1 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(roomCount < 20 ? Constants.accentColor : .gray)
                        }
                        .disabled(roomCount >= 20)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                // Bedrooms stepper
                HStack {
                    Text("Bedrooms")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 16) {
                        Button { if bedroomCount > 0 { bedroomCount -= 1 } } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(bedroomCount > 0 ? Constants.accentColor : .gray)
                        }
                        .disabled(bedroomCount <= 0)
                        Text("\(bedroomCount)")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(width: 36)
                        Button { if bedroomCount < roomCount { bedroomCount += 1 } } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(bedroomCount < roomCount ? Constants.accentColor : .gray)
                        }
                        .disabled(bedroomCount >= roomCount)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .onChange(of: roomCount) {
                if bedroomCount > roomCount { bedroomCount = roomCount }
            }

            // Room name preview
            let names = generateRoomNames(total: roomCount, bedrooms: bedroomCount)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Constants.accentColor.opacity(0.3), in: Capsule())
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        let nameIsEmpty = homeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isDisabled = currentStep == 1 && nameIsEmpty

        return Button {
            if currentStep < totalSteps - 1 {
                withAnimation { currentStep += 1 }
            } else {
                createHomeAndFinish()
            }
        } label: {
            Text(currentStep == 0 ? "Get Started" : currentStep == totalSteps - 1 ? "Create My Home" : "Next")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    (isDisabled ? Color.gray : Constants.accentColor).opacity(currentStep == 0 ? 1.0 : 0.9),
                    in: RoundedRectangle(cornerRadius: 14)
                )
        }
        .disabled(isDisabled)
        .padding(.horizontal, 32)
        .padding(.bottom, 40)
    }

    // MARK: - Climate Detection

    private func triggerClimateDetection() {
        // If address was resolved via autocomplete/location, use stored coordinate directly
        if let coord = addressService.selectedCoordinate {
            let lat = coord.latitude
            let zone: ClimateZone
            if lat < 32 { zone = .hot }
            else if lat < 40 { zone = .moderate }
            else { zone = .cold }

            // Reverse-geocode for city name display
            CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: coord.longitude)) { placemarks, _ in
                let city = placemarks?.first.flatMap {
                    [$0.locality, $0.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                }
                Task { @MainActor in
                    if let city, !city.isEmpty { locationDetector.detectedCity = city }
                    climateZone = zone
                }
            }
            return
        }

        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedAddress.isEmpty {
            // Address entered — geocode it (no location permission needed)
            locationDetector.geocodeAddress(trimmedAddress) { zone in
                if let zone {
                    climateZone = zone
                } else {
                    // Geocode failed — fall back to GPS
                    locationDetector.detectClimateZoneViaGPS { gpsZone in
                        if let gpsZone { climateZone = gpsZone }
                    }
                }
            }
        } else {
            // No address — use GPS (will prompt for permission)
            locationDetector.detectClimateZoneViaGPS { zone in
                if let zone { climateZone = zone }
            }
        }
    }

    // MARK: - Room Name Generation

    private func generateRoomNames(total: Int, bedrooms: Int) -> [String] {
        if total == 1 { return ["Main Room"] }

        var names: [String] = ["Living Room"]
        let remaining = total - 1 - bedrooms
        if remaining >= 1 && total >= 3 { names.append("Kitchen") }

        for i in 1...max(bedrooms, 1) {
            if names.count >= total { break }
            names.append(bedrooms == 1 ? "Bedroom" : "Bedroom \(i)")
        }

        let extras = ["Bathroom", "Dining Room", "Office", "Laundry Room", "Garage", "Hallway", "Basement", "Attic"]
        var extraIndex = 0
        while names.count < total && extraIndex < extras.count {
            names.append(extras[extraIndex])
            extraIndex += 1
        }
        // Fallback for very high counts
        var suffix = 1
        while names.count < total {
            names.append("Room \(suffix)")
            suffix += 1
        }

        return Array(names.prefix(total))
    }

    // MARK: - Create Home

    private func createHomeAndFinish() {
        let finalName = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let home = Home(
            name: finalName.isEmpty ? "My Home" : finalName,
            address: trimmedAddress.isEmpty ? nil : trimmedAddress,
            yearBuilt: yearBuilt,
            totalSqFt: Double(sqFtText),
            climateZone: climateZone,
            homeType: homeType,
            bedroomCount: bedroomCount
        )
        modelContext.insert(home)

        // Create placeholder rooms
        let roomNames = generateRoomNames(total: roomCount, bedrooms: bedroomCount)
        for name in roomNames {
            let room = Room(name: name, squareFootage: 0, scanWasUsed: false)
            room.home = home
            modelContext.insert(room)
        }

        didFinish = true
        hasSeenOnboarding = true
    }
}
