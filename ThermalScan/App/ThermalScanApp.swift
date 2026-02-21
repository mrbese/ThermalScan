import SwiftUI
import SwiftData

@main
struct ThermalScanApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: Room.self)
    }
}
