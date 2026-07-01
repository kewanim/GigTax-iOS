//
//  ContentView.swift
//  GigTax
//
//  Created by Kewani Mulugeta on 7/1/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
                TripsView()
                    .tabItem { Label("Trips", systemImage: "location.fill") }
                EarningsView()
                    .tabItem { Label("Earnings", systemImage: "dollarsign.circle.fill") }
                ExpensesView()
                    .tabItem { Label("Expenses", systemImage: "receipt.fill") }
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
}
