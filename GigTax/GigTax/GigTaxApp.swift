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
            DriverProfile.self,
            Vehicle.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
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
