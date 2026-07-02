import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService

    @Query private var vehicles: [Vehicle]

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
            .task {
                locationService.modelContext = modelContext
                if let v = vehicles.first {
                    locationService.cityMPG    = v.cityMPG
                    locationService.highwayMPG = v.highwayMPG
                }
                locationService.startMonitoring()
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environment(LocationService())
}
