import SwiftUI
import SwiftData

@main
struct ManorOSApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    let modelContainer: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        // Explicitly disable CloudKit sync (not using CloudKit)
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        // Attempt 1: Versioned schema with migration plan
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ManorOSMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            #if DEBUG
            print("[ManorOS] Versioned container failed: \(error)")
            print("[ManorOS] Attempting legacy store upgrade...")
            #endif
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
            #if DEBUG
            print("[ManorOS] Legacy store stamped, retrying versioned...")
            #endif

            return try ModelContainer(
                for: schema,
                migrationPlan: ManorOSMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            #if DEBUG
            print("[ManorOS] Legacy upgrade failed: \(error)")
            print("[ManorOS] Deleting store and starting fresh...")
            #endif
        }

        // Attempt 3: Delete corrupted store and recreate
        let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path() + suffix))
        }

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: ManorOSMigrationPlan.self,
                configurations: [config]
            )
        } catch {
            fatalError("Cannot create ModelContainer even after store reset: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(modelContainer)
    }
}
