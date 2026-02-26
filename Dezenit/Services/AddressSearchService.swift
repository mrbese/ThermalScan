import Foundation
import MapKit
import CoreLocation

@MainActor
final class AddressSearchService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var selectedAddress: String?
    @Published var isResolving: Bool = false

    // MARK: - Private

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?

    // MARK: - Init

    override init() {
        super.init()
        completer.resultTypes = .address
        completer.delegate = self
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public Methods

    func updateQuery(_ fragment: String) {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 3 {
            completer.cancel()
            suggestions = []
            return
        }
        completer.queryFragment = trimmed
    }

    func selectSuggestion(_ completion: MKLocalSearchCompletion) async {
        suggestions = []
        completer.cancel()
        isResolving = true
        defer { isResolving = false }

        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = .address

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard let item = response.mapItems.first else { return }
            selectedCoordinate = item.placemark.coordinate
            selectedAddress = formatPlacemark(item.placemark)
        } catch {
            // Search failed — leave state unchanged
        }
    }

    func useCurrentLocation() async {
        isResolving = true
        defer { isResolving = false }

        // Request permission if needed
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for authorization callback
            try? await Task.sleep(for: .seconds(1))
            // Re-check after prompt
            guard locationManager.authorizationStatus == .authorizedWhenInUse
               || locationManager.authorizationStatus == .authorizedAlways else { return }
        } else if status == .denied || status == .restricted {
            return
        }

        do {
            let location = try await requestSingleLocation()
            selectedCoordinate = location.coordinate

            let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                selectedAddress = formatPlacemark(MKPlacemark(placemark: placemark))
            }
        } catch {
            // Location or geocode failed
        }
    }

    func clear() {
        suggestions = []
        selectedCoordinate = nil
        selectedAddress = nil
        isResolving = false
        completer.cancel()
    }

    // MARK: - Helpers

    private func requestSingleLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func formatPlacemark(_ pm: MKPlacemark) -> String {
        let parts: [String?] = [
            pm.subThoroughfare,
            pm.thoroughfare
        ]
        let street = parts.compactMap { $0 }.joined(separator: " ")

        let components: [String?] = [
            street.isEmpty ? nil : street,
            pm.locality,
            pm.administrativeArea,
            pm.postalCode
        ]
        return components.compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension AddressSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor in
            self.suggestions = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension AddressSearchService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                self.locationContinuation?.resume(returning: location)
                self.locationContinuation = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(throwing: error)
            self.locationContinuation = nil
        }
    }
}
