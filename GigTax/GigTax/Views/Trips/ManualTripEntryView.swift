import SwiftUI
import SwiftData

struct ManualTripEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService

    @State private var date = Date()
    @State private var distanceText = ""
    @State private var cityPct: Double = 55
    @State private var tripType = TripType.business
    @State private var purpose = ""

    private var distance: Double { Double(distanceText) ?? 0 }
    private var canSave: Bool { distance > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date & Time", selection: $date,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Section("Distance") {
                    LabeledContent("Miles") {
                        TextField("e.g. 12.5", text: $distanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("City driving")
                            Spacer()
                            Text("\(Int(cityPct))%").foregroundStyle(.secondary)
                        }
                        Slider(value: $cityPct, in: 0...100, step: 5)
                    }
                    .padding(.vertical, 4)
                }

                Section("Classification") {
                    Picker("Trip Type", selection: $tripType) {
                        Text("Business").tag(TripType.business)
                        Text("Personal").tag(TripType.personal)
                    }
                    .pickerStyle(.segmented)

                    if tripType == .business {
                        TextField("Business purpose (optional)", text: $purpose)
                            .autocorrectionDisabled()
                    }
                }
            }
            .navigationTitle("Log Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cityMiles = distance * (cityPct / 100)
        let hwyMiles  = distance * (1 - cityPct / 100)
        let gallons = (locationService.cityMPG > 0 ? cityMiles / locationService.cityMPG : 0)
                    + (locationService.highwayMPG > 0 ? hwyMiles / locationService.highwayMPG : 0)

        let trip = Trip(startDate: date, isManualEntry: true)
        trip.endDate              = date
        trip.distanceMiles        = distance
        trip.cityMiles            = cityMiles
        trip.highwayMiles         = hwyMiles
        trip.tripTypeRaw          = tripType.rawValue
        trip.businessPurpose      = purpose
        trip.estimatedFuelGallons = gallons
        trip.estimatedFuelCost    = gallons * locationService.gasPrice

        modelContext.insert(trip)
        if tripType == .business, let fuelExpense = Expense.fuelExpense(for: trip) {
            modelContext.insert(fuelExpense)
        }

        // Required hook: manual entries never touch LocationService.endTrip,
        // so without this call a driver who logs trips by hand (exactly the
        // case GPS-gap-filling exists for) would never trigger a maintenance check.
        if let vehicle = locationService.vehicle {
            MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
        }

        dismiss()
    }
}

#Preview {
    ManualTripEntryView()
        .environment(LocationService())
        .modelContainer(for: Trip.self, inMemory: true)
}
