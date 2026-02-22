import Foundation
import CoreLocation

@MainActor
class StateDetectionService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var detectedState: USState?
    @Published var isDetecting = false

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func detectState() {
        guard detectedState == nil, !isDetecting else { return }
        isDetecting = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            isDetecting = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            } else if status == .denied || status == .restricted {
                isDetecting = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        Task { @MainActor in
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let state = placemarks.first?.administrativeArea {
                    detectedState = USState.from(administrativeArea: state)
                }
            } catch {
                // Silently fail — rebates section just won't show
            }
            isDetecting = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isDetecting = false
        }
    }
}
