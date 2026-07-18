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
    @State private var biometricLockService = BiometricLockService()
    @State private var cloudSyncStatusService = CloudSyncStatusService()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer { GigTaxModelContainer.shared }

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTestReset") {
            Self.resetStateForUITesting()
        }
        // Must register before the app finishes launching, per BGTaskScheduler docs.
        BackgroundTaskManager.register(locationService: locationService)
    }

    /// UI tests assume a fresh, post-onboarding, empty-data state on every launch —
    /// rather than relying on whatever the simulator happened to have persisted from
    /// prior manual runs (fragile: broke the whole suite after an unrelated simulator
    /// reset), wipe transactional data and seed the minimum onboarding-complete state.
    private static func resetStateForUITesting() {
        let context = GigTaxModelContainer.shared.mainContext
        for shift in (try? context.fetch(FetchDescriptor<Shift>())) ?? [] { context.delete(shift) }
        for expense in (try? context.fetch(FetchDescriptor<Expense>())) ?? [] { context.delete(expense) }
        for trip in (try? context.fetch(FetchDescriptor<Trip>())) ?? [] { context.delete(trip) }
        for payment in (try? context.fetch(FetchDescriptor<QuarterlyPayment>())) ?? [] { context.delete(payment) }
        for item in (try? context.fetch(FetchDescriptor<MaintenanceScheduleItem>())) ?? [] { context.delete(item) }

        if (try? context.fetch(FetchDescriptor<DriverProfile>()))?.isEmpty ?? true {
            let profile = DriverProfile()
            profile.filingStatus = .single
            profile.state = "MD"
            profile.county = "Montgomery"
            context.insert(profile)
        }
        if (try? context.fetch(FetchDescriptor<Vehicle>()))?.isEmpty ?? true {
            let vehicle = Vehicle(make: "Toyota", model: "Camry", year: 2022, cityMPG: 28, highwayMPG: 39, startingOdometer: 10_000)
            context.insert(vehicle)
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(biometricLockService)
                .environment(cloudSyncStatusService)
                .onAppear {
                    UIApplication.shared.addKeyboardDismissRecognizer()
                }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.schedule()
            }
        }
    }
}
