import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var driverProfiles: [DriverProfile]
    @Environment(\.modelContext) private var modelContext

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var biometricLockBinding: Binding<Bool> {
        Binding(
            get: { driverProfile?.biometricLockEnabled ?? false },
            set: { driverProfile?.biometricLockEnabled = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Face ID / Touch ID Lock", isOn: biometricLockBinding)
                } footer: {
                    Text("Requires biometric authentication (or your device passcode) whenever GigTax returns from the background.")
                }

                Section {
                    NavigationLink {
                        DataExportView()
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up.on.square")
                    }
                } footer: {
                    Text("Full backup of your shifts, trips, and expenses as JSON or CSV.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: DriverProfile.self, inMemory: true)
}
