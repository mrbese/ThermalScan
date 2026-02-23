import Foundation
import RoomPlan
import ARKit
import CoreLocation
import simd

@MainActor
final class RoomCaptureService: NSObject, ObservableObject {
    enum State {
        case idle
        case scanning
        case processing
        case completed(squareFootage: Double, windows: [WindowInfo])
        case failed(Error)
        case unavailable
    }

    @Published var state: State = .idle

    private(set) var captureView: RoomCaptureView?

    // Compass heading captured as soon as scanning starts
    private var locationManager: CLLocationManager?
    private var capturedHeading: Double?

    override init() {
        super.init()
        guard RoomCaptureSession.isSupported else {
            state = .unavailable
            return
        }
        let view = RoomCaptureView()
        captureView = view
        view.captureSession.delegate = self
    }

    func startSession() {
        capturedHeading = nil
        startCapturingHeading()
        let config = RoomCaptureSession.Configuration()
        captureView?.captureSession.run(configuration: config)
        state = .scanning
    }

    func stopSession() {
        captureView?.captureSession.stop()
        locationManager?.stopUpdatingHeading()
        state = .processing
    }

    func reset() {
        state = .idle
    }

    static var isLiDARAvailable: Bool {
        RoomCaptureSession.isSupported
    }

    private func startCapturingHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        let mgr = CLLocationManager()
        mgr.headingFilter = kCLHeadingFilterNone
        mgr.delegate = self
        locationManager = mgr
        mgr.startUpdatingHeading()
    }
}

// MARK: - CLLocationManagerDelegate (compass heading)

extension RoomCaptureService: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // Keep refreshing so we always have the latest heading during scan
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        capturedHeading = h
    }
}

// MARK: - RoomCaptureSessionDelegate

extension RoomCaptureService: RoomCaptureSessionDelegate {
    nonisolated func captureSession(
        _ session: RoomCaptureSession,
        didEndWith data: CapturedRoomData,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in self.state = .failed(error) }
            return
        }
        buildFinalRoom(from: data)
    }

    nonisolated private func buildFinalRoom(from data: CapturedRoomData) {
        Task { @MainActor in
            let heading = capturedHeading
            locationManager?.stopUpdatingHeading()
            do {
                let room = try await RoomBuilder(options: [.beautifyObjects]).capturedRoom(from: data)
                let sqMeters = Self.estimateFloorArea(from: room)
                let windows = Self.extractWindows(from: room, deviceHeading: heading)
                self.state = .completed(
                    squareFootage: max(sqMeters * 10.7639, 0),
                    windows: windows
                )
            } catch {
                self.state = .failed(error)
            }
        }
    }

    nonisolated private func captureSession(
        _ session: RoomCaptureSession,
        didUpdate room: CapturedRoomData
    ) {}
}

// MARK: - Geometry helpers

extension RoomCaptureService {

    /// Floor area in sq meters. Tries detected floors first, falls back to wall bounding box.
    nonisolated static func estimateFloorArea(from room: CapturedRoom) -> Double {
        let floorArea = room.floors.reduce(0.0) {
            $0 + Double($1.dimensions.x) * Double($1.dimensions.z)
        }
        if floorArea > 0 { return floorArea }

        // Fallback: bounding box of wall edge points in XZ plane
        var pts: [SIMD2<Float>] = []
        for wall in room.walls {
            let t = wall.transform
            let cx = t.columns.3.x, cz = t.columns.3.z
            let hw = wall.dimensions.x / 2
            let rx = t.columns.0.x, rz = t.columns.0.z
            pts.append(SIMD2(cx + rx * hw, cz + rz * hw))
            pts.append(SIMD2(cx - rx * hw, cz - rz * hw))
        }
        guard !pts.isEmpty else { return 0 }
        let xs = pts.map(\.x), zs = pts.map(\.y)
        return Double((xs.max()! - xs.min()!) * (zs.max()! - zs.min()!))
    }

    /// Extract detected windows, auto-assigning cardinal direction from compass heading.
    nonisolated static func extractWindows(
        from room: CapturedRoom,
        deviceHeading: Double?
    ) -> [WindowInfo] {
        guard !room.windows.isEmpty else { return [] }

        // Room centroid in XZ from wall positions
        let wallXZ = room.walls.map { SIMD2<Float>($0.transform.columns.3.x, $0.transform.columns.3.z) }
        let center: SIMD2<Float> = wallXZ.isEmpty
            ? .zero
            : wallXZ.reduce(.zero, +) / Float(wallXZ.count)

        return room.windows.map { window in
            // Vector from room center to window position = outward direction
            let dx = Double(window.transform.columns.3.x - center.x)
            let dz = Double(window.transform.columns.3.z - center.y)

            let direction = cardinalDirection(dx: dx, dz: dz, heading: deviceHeading)
            let size = sizeCategory(dimensions: window.dimensions)
            return WindowInfo(direction: direction, size: size)
        }
    }

    /// Convert ARKit-space offset (dx, dz) + device compass heading to cardinal direction.
    ///
    /// Formula: compassAngle = heading + atan2(dx, -dz)
    ///   • ARKit -Z = device forward at scan start = `heading` degrees from North
    ///   • atan2(dx, -dz) gives clockwise angle from -Z axis
    nonisolated static func cardinalDirection(dx: Double, dz: Double, heading: Double?) -> CardinalDirection {
        let len = (dx * dx + dz * dz).squareRoot()
        guard len > 0.05 else { return .south }

        let angleFromForward = atan2(dx, -dz) * 180.0 / .pi
        var compass = ((heading ?? 0) + angleFromForward).truncatingRemainder(dividingBy: 360)
        if compass < 0 { compass += 360 }

        switch compass {
        case 315..<360, 0..<45: return .north
        case 45..<135:          return .east
        case 135..<225:         return .south
        case 225..<315:         return .west
        default:                return .north
        }
    }

    /// Map window dimensions (meters) to Small / Medium / Large.
    nonisolated static func sizeCategory(dimensions: simd_float3) -> WindowSize {
        let sqFt = Double(dimensions.x * dimensions.y) * 10.7639
        if sqFt < 15 { return .small }
        if sqFt < 27 { return .medium }
        return .large
    }
}
