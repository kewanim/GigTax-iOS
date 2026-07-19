import SwiftUI
import SwiftData

struct GasPriceSettingsView: View {
    @Query private var driverProfiles: [DriverProfile]
    @Environment(LocationService.self) private var locationService

    @State private var apiKeyText = ""
    @State private var isRefreshing = false

    private var driverProfile: DriverProfile? { driverProfiles.first }

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "fuelpump.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locationService.gasPrice, format: .currency(code: "USD"))
                            .font(.subheadline).fontWeight(.semibold)
                        if let status = locationService.gasPriceStatus {
                            Text(status.isLive ? "Live — \(status.regionName), week of \(status.weekOf)" : status.regionName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not yet checked this launch")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
            } header: {
                Text("Current Price Used for Fuel Estimates")
            } footer: {
                Text("Without a free EIA key below, GigTax uses a per-state average estimate rather than your exact local price. Every fuel cost and actual-expense-method deduction depends on this number being close to real.")
            }

            Section {
                TextField("EIA API Key (optional)", text: $apiKeyText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button {
                    save()
                } label: {
                    Text("Save & Refresh")
                }
                .disabled(apiKeyText.isEmpty || apiKeyText == (driverProfile?.eiaAPIKey ?? ""))
            } header: {
                Text("Live Daily Prices (Optional)")
            } footer: {
                Text("Free, no credit card: sign up at eia.gov/opendata/register.php, then paste the key here. Unlocks real, regularly-updating regional gas prices instead of the state-average estimate.")
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    } else {
                        Text("Check Now")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .navigationTitle("Gas Price")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { apiKeyText = driverProfile?.eiaAPIKey ?? "" }
    }

    private func save() {
        driverProfile?.eiaAPIKey = apiKeyText.isEmpty ? nil : apiKeyText
        Task { await refresh() }
    }

    private func refresh() async {
        isRefreshing = true
        await locationService.refreshGasPrice(state: driverProfile?.state ?? "MD", apiKey: driverProfile?.eiaAPIKey)
        isRefreshing = false
    }
}

#Preview {
    NavigationStack {
        GasPriceSettingsView()
            .modelContainer(for: DriverProfile.self, inMemory: true)
            .environment(LocationService())
    }
}
