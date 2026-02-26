import SwiftUI
import SwiftData

@main
struct DezenitApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        // Explicitly disable CloudKit sync (entitlements have it ON but we're not ready yet)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        // Attempt 1: Versioned schema with migration plan
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: DezenitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            print("[Dezenit] Versioned container failed: \(error)")
            print("[Dezenit] Attempting legacy store upgrade...")
        }

        // Attempt 2: Existing store was created without VersionedSchema.
        // Load it unversioned to stamp version metadata, then retry.
        do {
            let legacyConfig = ModelConfiguration(cloudKitDatabase: .none)
            let legacyContainer = try ModelContainer(
                for: Home.self, Room.self, Equipment.self,
                     Appliance.self, EnergyBill.self, AuditProgress.self,
                configurations: legacyConfig
            )
            try legacyContainer.mainContext.save()
            print("[Dezenit] Legacy store stamped, retrying versioned...")

            return try ModelContainer(
                for: schema,
                migrationPlan: DezenitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            print("[Dezenit] Legacy upgrade failed: \(error)")
            print("[Dezenit] Deleting store and starting fresh...")
        }

        // Attempt 3: Delete corrupted store and recreate
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path() + suffix))
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: DezenitMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Cannot create ModelContainer even after store reset: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                HomeListView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(modelContainer)
    }
}
