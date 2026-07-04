import SwiftUI
import SwiftData

struct ScheduleCSummaryView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]

    let taxYear: Int

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var grossIncome: Double {
        shifts.filter { $0.taxYear == taxYear }.reduce(0) { $0 + $1.totalIncome }
    }

    private var comparison: DeductionMethodCalculator.Comparison {
        DeductionMethodCalculator.compare(
            trips: trips.filter { $0.taxYear == taxYear },
            expenses: expenses.filter { $0.taxYear == taxYear },
            phoneBusinessPercent: driverProfile?.phoneBusinessPercent ?? 100
        )
    }

    private var summary: ScheduleCMapper.Summary {
        ScheduleCMapper.summary(
            comparison: comparison,
            method: driverProfile?.preferredDeductionMethod ?? .standard,
            grossIncome: grossIncome
        )
    }

    var body: some View {
        List {
            Section {
                ForEach(summary.lineItems, id: \.line) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.line).font(.caption).foregroundStyle(.secondary)
                            Text(item.label)
                        }
                        Spacer()
                        Text(item.amount, format: .currency(code: "USD"))
                            .fontWeight(item.line == "Line 31" ? .bold : .regular)
                    }
                }
            } header: {
                Text("Schedule C — Tax Year \(String(taxYear))")
            } footer: {
                Text("These figures come directly from your logged shifts, trips, and expenses using your currently selected deduction method (\(driverProfile?.preferredDeductionMethod == .actual ? "Actual Expense" : "Standard Mileage")). Enter them on the matching lines of Schedule C (Form 1040).")
            }
        }
        .navigationTitle("Schedule C")
    }
}

#Preview {
    NavigationStack {
        ScheduleCSummaryView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self], inMemory: true)
}
