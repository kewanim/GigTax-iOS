import SwiftUI
import SwiftData

@Observable
final class OnboardingData {
    // Vehicle
    var makeId: Int = 0
    var makeName: String = ""
    var modelName: String = ""
    var vehicleYear: Int = Calendar.current.component(.year, from: .now)
    var cityMPG: Double = 0
    var highwayMPG: Double = 0
    var startingOdometer: Double = 0

    // Tax profile
    var filingStatus: FilingStatus = .single
    var state: String = "MD"
    var county: String = "Montgomery"
    var weeklyGoal: String = ""
    var monthlyGoal: String = ""
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var page = 0
    @State private var data = OnboardingData()

    var body: some View {
        TabView(selection: $page) {
            WelcomeView(onNext: { page = 1 })
                .tag(0)

            VehicleSetupView(data: data, onNext: { page = 2 }, onBack: { page = 0 })
                .tag(1)

            ProfileSetupView(data: data, onNext: { page = 3 }, onBack: { page = 1 })
                .tag(2)

            PermissionsView(onFinish: { finish() }, onBack: { page = 2 })
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(.easeInOut, value: page)
        .ignoresSafeArea()
    }

    private func finish() {
        let profile = DriverProfile()
        profile.filingStatus = data.filingStatus
        profile.state = data.state
        profile.county = data.county
        profile.weeklyGoal = Double(data.weeklyGoal)
        profile.monthlyGoal = Double(data.monthlyGoal)
        modelContext.insert(profile)

        let vehicle = Vehicle(
            make: data.makeName,
            model: data.modelName,
            year: data.vehicleYear,
            cityMPG: data.cityMPG,
            highwayMPG: data.highwayMPG,
            startingOdometer: data.startingOdometer
        )
        modelContext.insert(vehicle)

        try? modelContext.save()
        hasCompletedOnboarding = true
    }
}
