import SwiftUI
import SwiftData

struct OdometerCheckInView: View {
    let vehicle: Vehicle

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]

    @State private var readingText = ""
    @State private var showLowerReadingConfirm = false

    private var estimatedOdometer: Double {
        OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: trips)
    }
    private var reading: Double { Double(readingText) ?? 0 }
    private var canSave: Bool { reading > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("GigTax estimates") {
                        Text("\(Int(estimatedOdometer)) mi").foregroundStyle(.secondary)
                    }
                    LabeledContent("Actual reading") {
                        TextField("\(Int(estimatedOdometer))", text: $readingText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("GPS-tracked miles drift from your car's true odometer over time (trips outside tracking, phone left home, etc). Confirming here resets the baseline GigTax uses for maintenance reminders.")
                }
            }
            .navigationTitle("Confirm Odometer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { attemptSave() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog(
                "That's lower than your last confirmed reading of \(Int(vehicle.lastConfirmedOdometer)) mi — are you sure?",
                isPresented: $showLowerReadingConfirm,
                titleVisibility: .visible
            ) {
                Button("Yes, that's correct") { save() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func attemptSave() {
        if reading < vehicle.lastConfirmedOdometer {
            showLowerReadingConfirm = true
        } else {
            save()
        }
    }

    private func save() {
        vehicle.lastConfirmedOdometer = reading
        vehicle.lastConfirmedOdometerDate = .now
        MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
        dismiss()
    }
}

#Preview {
    OdometerCheckInView(vehicle: Vehicle())
        .modelContainer(for: Vehicle.self, inMemory: true)
}
