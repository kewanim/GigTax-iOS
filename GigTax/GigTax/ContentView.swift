import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Environment(BiometricLockService.self) private var lockService
    @Environment(\.scenePhase) private var scenePhase

    @Query private var vehicles: [Vehicle]
    @Query private var driverProfiles: [DriverProfile]

    private let navigationCoordinator = AppNavigationCoordinator.shared

    private var biometricLockEnabled: Bool {
        driverProfiles.first?.biometricLockEnabled ?? false
    }

    private var pendingDestinationBinding: Binding<AppNavigationCoordinator.Destination?> {
        Binding(
            get: { navigationCoordinator.pendingDestination },
            set: { navigationCoordinator.pendingDestination = $0 }
        )
    }

    var body: some View {
        if hasCompletedOnboarding {
            ZStack {
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
                        locationService.vehicle    = v
                    }
                    let profile = driverProfiles.first
                    locationService.driverProfile = profile
                    locationService.restoreShiftState(active: profile?.isShiftActive ?? false, startDate: profile?.shiftStartDate)
                    locationService.startMonitoring()
                    await locationService.refreshGasPrice(state: profile?.state ?? "MD", apiKey: profile?.eiaAPIKey)
                }

                if lockService.isLocked {
                    LockScreenView(lockService: lockService)
                        .transition(.opacity)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background, biometricLockEnabled {
                    lockService.lock()
                }
            }
            .sheet(item: pendingDestinationBinding) { destination in
                switch destination {
                case .logShift(let platform):
                    ManualShiftEntryView(defaultPlatform: platform)
                }
            }
        } else {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        }
    }
}

#Preview {
    ContentView()
        .environment(LocationService())
        .environment(BiometricLockService())
}
