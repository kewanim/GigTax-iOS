import SwiftUI
import SwiftData

struct AuditShieldView: View {
    @Query private var driverProfiles: [DriverProfile]
    @Query private var vehicles: [Vehicle]
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var taxYear = Calendar.current.component(.year, from: .now)
    @State private var showNamePrompt = false
    @State private var nameInput = ""
    @State private var exportURL: URL?

    private var driverProfile: DriverProfile? { driverProfiles.first }
    private var vehicle: Vehicle? { vehicles.first }

    private var yearTrips: [Trip] { trips.filter { $0.taxYear == taxYear } }
    private var totals: MileageLogPDFGenerator.Totals { MileageLogPDFGenerator.totals(trips: yearTrips) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("What triggers an audit?", systemImage: "exclamationmark.shield")
                        .font(.headline)
                    Text("The IRS most commonly flags self-employed drivers for large mileage deductions relative to income, or a mileage log that looks estimated rather than tracked day-by-day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("How this protects you", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                        .padding(.top, 6)
                    Text("Every trip below was recorded by GPS as it happened — date, route, and distance — not reconstructed from memory afterward. That contemporaneous record is exactly what the IRS asks for if a deduction is ever questioned.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Label("What else to keep", systemImage: "folder")
                        .font(.headline)
                        .padding(.top, 6)
                    Text("Fuel and maintenance receipts, your odometer reading at the start and end of the year, and this mileage log — together they support either deduction method if you're ever asked.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Your \(String(taxYear)) Mileage Log") {
                LabeledContent("Business Trips", value: "\(totals.tripCount)")
                LabeledContent("Total Miles", value: String(format: "%.1f", totals.totalMiles))
                LabeledContent("Standard Deduction", value: totals.totalDeduction.formatted(.currency(code: "USD")))
                NavigationLink("View Full Log") {
                    MileageLogView(taxYear: taxYear)
                }
            }

            Section {
                if let exportURL {
                    ShareLink(item: exportURL, preview: SharePreview("Mileage Log \(String(taxYear)).pdf")) {
                        Label("Export Mileage Log PDF", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        beginExport()
                    } label: {
                        Label("Export Mileage Log PDF", systemImage: "square.and.arrow.up")
                    }
                    .disabled(totals.tripCount == 0)
                }
            } footer: {
                if totals.tripCount == 0 {
                    Text("Log at least one business trip this year to export a PDF.")
                }
            }
        }
        .navigationTitle("Audit Shield")
        .sheet(isPresented: $showNamePrompt) {
            DriverNamePromptView(initialName: nameInput) { name in
                driverProfile?.driverName = name
                showNamePrompt = false
                generateAndExport(driverName: name)
            }
        }
    }

    private func beginExport() {
        if let name = driverProfile?.driverName, !name.isEmpty {
            generateAndExport(driverName: name)
        } else {
            showNamePrompt = true
        }
    }

    private func generateAndExport(driverName: String) {
        let vehicleDescription = vehicle.map { "\($0.year) \($0.make) \($0.model)" }
        let data = MileageLogPDFGenerator.generate(trips: yearTrips, driverName: driverName, vehicleDescription: vehicleDescription, taxYear: taxYear)

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("MileageLog-\(taxYear).pdf")
        do {
            try data.write(to: fileURL)
            exportURL = fileURL
        } catch {
            // Writing to the app's own temp directory failing is not a
            // recoverable, actionable state for the driver — nothing to
            // retry differently. Just don't present a broken share sheet.
        }
    }
}

private struct DriverNamePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let onSave: (String) -> Void

    init(initialName: String, onSave: @escaping (String) -> Void) {
        _name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                        .autocorrectionDisabled()
                } footer: {
                    Text("Shown on the mileage log PDF so it's identifiable as yours if you ever need to share it.")
                }
            }
            .navigationTitle("Your Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Continue") {
                        onSave(name)
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AuditShieldView()
    }
    .modelContainer(for: [Trip.self, DriverProfile.self, Vehicle.self], inMemory: true)
}
