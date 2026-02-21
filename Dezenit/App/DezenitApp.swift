import SwiftUI
import SwiftData

@main
struct DezenitApp: App {
    var body: some Scene {
        WindowGroup {
            HomeListView()
        }
        .modelContainer(for: [Home.self, Room.self, Equipment.self])
    }
}
