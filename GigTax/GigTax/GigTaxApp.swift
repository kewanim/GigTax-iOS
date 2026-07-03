//
//  GigTaxApp.swift
//  GigTax
//
//  Created by Kewani Mulugeta on 7/1/26.
//

import SwiftUI
import SwiftData

@main
struct GigTaxApp: App {
    @State private var locationService = LocationService()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
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

    init() {
        // Must register before the app finishes launching, per BGTaskScheduler docs.
        BackgroundTaskManager.register(locationService: locationService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.schedule()
            }
        }
    }
}
