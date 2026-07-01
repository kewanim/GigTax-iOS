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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
