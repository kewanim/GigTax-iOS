import Foundation
import SwiftData

/// The single shared SwiftData container — extracted to a standalone static
/// so App Intents and the widget extension (which run outside the App
/// struct's own lifecycle, in the widget's case an entirely separate
/// process) can reach the same on-disk store the rest of the app uses.
/// The store lives in the shared App Group container rather than the main
/// app's private sandbox specifically so the widget extension process can
/// read it directly.
enum GigTaxModelContainer {
    static let appGroupIdentifier = "group.com.kewani-is-th.GigTax"

    static let shared: ModelContainer = {
        let schema = Schema([
            Shift.self,
            Trip.self,
            Expense.self,
            RecurringExpense.self,
            MaintenanceScheduleItem.self,
            QuarterlyPayment.self,
            DriverProfile.self,
            Vehicle.self,
        ])

        // XCTest (unit or UI) sets this env var for any launch it drives.
        // Under test, use a private in-memory store with CloudKit disabled —
        // otherwise a UI test's "fresh" local store still re-syncs down
        // whatever's sitting in the real CloudKit container, including any
        // old/broken records from prior schema versions. Tests should never
        // depend on real cloud state anyway.
        let isRunningUnderTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        let modelConfiguration: ModelConfiguration
        if isRunningUnderTest {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        } else if let sharedContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            let storeURL = sharedContainerURL.appendingPathComponent("GigTax.sqlite")
            modelConfiguration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .automatic)
        } else {
            // App Group container unavailable (e.g. entitlement not yet
            // provisioned on this build) — fall back to the default
            // per-process location rather than crashing outright. The
            // widget just won't see live data until this resolves.
            modelConfiguration = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        }

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
