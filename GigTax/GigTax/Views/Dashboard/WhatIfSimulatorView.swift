import SwiftUI
import SwiftData

struct WhatIfSimulatorView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var recurringExpenses: [RecurringExpense]

    let taxYear: Int

    @State private var extraMiles: Double = 100

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var result: WhatIfSimulator.Result {
        WhatIfSimulator.simulate(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, extraMiles: extraMiles, recurringExpenses: recurringExpenses)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("What if I drove \(Int(extraMiles)) more business miles this year?")
                        .font(.headline)
                    Slider(value: $extraMiles, in: 0...5_000, step: 50)
                    HStack {
                        Text("0 mi").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("5,000 mi").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                LabeledContent("Extra Deduction") {
                    Text(result.extraDeduction, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
                LabeledContent("Tax Savings") {
                    Text(result.taxSavings, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                LabeledContent("Net Income Gain") {
                    Text(result.netIncomeDelta, format: .currency(code: "USD"))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Impact")
            } footer: {
                Text("Based on the standard mileage rate ($0.70/mi), holding your gross income the same — this isolates what tracking more business miles alone is worth.")
            }
        }
        .navigationTitle("What If?")
    }
}

#Preview {
    NavigationStack {
        WhatIfSimulatorView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self], inMemory: true)
}
