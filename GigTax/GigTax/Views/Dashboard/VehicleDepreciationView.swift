import SwiftUI
import SwiftData

struct VehicleDepreciationView: View {
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]

    let taxYear: Int

    @State private var purchasePriceText = ""
    @State private var placedInServiceDate = Date()
    @State private var useBonusDepreciation = true
    @State private var hasSetInitialValues = false

    private var vehicle: Vehicle? { vehicles.first }
    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var businessUsePercent: Double {
        let yearTrips = trips.filter { $0.taxYear == taxYear }
        let yearExpenses = expenses.filter { $0.taxYear == taxYear }
        return DeductionMethodCalculator.compare(
            trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: driverProfile?.phoneBusinessPercent ?? 100
        ).businessUsePercent
    }

    private var result: VehicleDepreciationCalculator.Result? {
        guard let purchasePrice = Double(purchasePriceText), purchasePrice > 0 else { return nil }
        return VehicleDepreciationCalculator.calculate(
            vehicleCost: purchasePrice, businessUsePercent: businessUsePercent, useBonusDepreciation: useBonusDepreciation
        )
    }

    private var currentScheduleYear: Int {
        VehicleDepreciationCalculator.scheduleYear(placedInServiceYear: Calendar.current.component(.year, from: placedInServiceDate), taxYear: taxYear)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What is Section 179?").font(.headline)
                    Text("Normally, a business vehicle's cost gets deducted a little at a time over several years (depreciation). Section 179 — plus \"bonus depreciation\" — lets you deduct much more of it upfront, in the year you start using it for business.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("The IRS caps how much of a passenger vehicle you can deduct each year — these limits exist specifically so people don't write off luxury cars all at once. This tool applies the actual 2025 IRS limits to your vehicle.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Label("You must use the vehicle more than 50% for business to qualify. If business use later drops to 50% or below, the IRS requires \"recapturing\" (paying back) some of what you deducted — this tool doesn't track that across years, so talk to a tax preparer if your business use is likely to drop.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
            }

            Section {
                VehicleInputRows(
                    purchasePriceText: $purchasePriceText,
                    placedInServiceDate: $placedInServiceDate,
                    useBonusDepreciation: $useBonusDepreciation,
                    businessUsePercent: businessUsePercent
                )
            } header: {
                Text("Your Vehicle")
            } footer: {
                Text("Business use % comes from your actual logged trips — not editable here.")
            }

            if businessUsePercent <= 50 {
                Section {
                    Label("Business use must be over 50% to qualify for Section 179 or bonus depreciation.", systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } else if let result, !result.schedule.isEmpty {
                Section {
                    ForEach(result.schedule, id: \.year) { entry in
                        HStack {
                            Text("Year \(entry.year)")
                                .fontWeight(entry.year == currentScheduleYear ? .bold : .regular)
                            if entry.year == currentScheduleYear {
                                Text("(\(String(taxYear)))").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.deduction, format: .currency(code: "USD"))
                                .fontWeight(entry.year == currentScheduleYear ? .bold : .regular)
                        }
                    }
                } header: {
                    Text("Depreciation Schedule")
                } footer: {
                    Text("Total depreciable basis: \(result.depreciableBasis.formatted(.currency(code: "USD"))). This year's deduction (\(String(taxYear))) feeds directly into your actual expense method total.")
                }
            }
        }
        .navigationTitle("Vehicle Depreciation")
        .onAppear {
            guard !hasSetInitialValues else { return }
            hasSetInitialValues = true
            if let vehicle {
                purchasePriceText = vehicle.purchasePrice.map { String($0) } ?? ""
                placedInServiceDate = vehicle.placedInServiceDate ?? Date()
                useBonusDepreciation = vehicle.useBonusDepreciation
            }
        }
        .onChange(of: purchasePriceText) { _, newValue in vehicle?.purchasePrice = Double(newValue) }
        .onChange(of: placedInServiceDate) { _, newValue in vehicle?.placedInServiceDate = newValue }
        .onChange(of: useBonusDepreciation) { _, newValue in vehicle?.useBonusDepreciation = newValue }
    }
}

private struct VehicleInputRows: View {
    @Binding var purchasePriceText: String
    @Binding var placedInServiceDate: Date
    @Binding var useBonusDepreciation: Bool
    let businessUsePercent: Double

    var body: some View {
        LabeledContent("Purchase Price") {
            TextField("$", text: $purchasePriceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        DatePicker("Placed in Service", selection: $placedInServiceDate, displayedComponents: .date)
        Toggle("Use Bonus Depreciation", isOn: $useBonusDepreciation)
        LabeledContent("Business Use") {
            Text("\(Int(businessUsePercent))%").foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        VehicleDepreciationView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: [Vehicle.self, Trip.self, Expense.self, DriverProfile.self], inMemory: true)
}
