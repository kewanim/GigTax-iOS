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
        // Must register before the app finishes launching, per BGTaskScheduler docs.
        BackgroundTaskManager.register(locationService: locationService)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationService)
                .environment(biometricLockService)
                .environment(cloudSyncStatusService)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundTaskManager.schedule()
            }
        }
    }
}
