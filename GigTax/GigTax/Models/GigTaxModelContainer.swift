import Foundation
import SwiftData

/// The single shared SwiftData container — extracted to a standalone static
/// so App Intents (which run outside the App struct's own lifecycle, even
/// when they open the app) can reach the same on-disk store the rest of the
/// app uses, without needing their own separate container wiring.
enum GigTaxModelContainer {
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
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isRunningUnderTest,
            cloudKitDatabase: isRunningUnderTest ? .none : .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
