import SwiftUI
import SwiftData

struct ScheduleCSummaryView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var vehicles: [Vehicle]
    @Query private var recurringExpenses: [RecurringExpense]

    let taxYear: Int

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var grossIncome: Double {
        shifts.filter { $0.taxYear == taxYear }.reduce(0) { $0 + $1.totalIncome }
    }

    private var comparison: DeductionMethodCalculator.Comparison {
        let yearTrips = trips.filter { $0.taxYear == taxYear }
        let yearExpenses = expenses.filter { $0.taxYear == taxYear }
        let phoneBusinessPercent = driverProfile?.phoneBusinessPercent ?? 100
        let preliminary = DeductionMethodCalculator.compare(trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: phoneBusinessPercent, recurringExpenses: recurringExpenses, taxYear: taxYear)
        let depreciation = TaxYearSummaryBuilder.depreciationDeduction(vehicle: vehicles.first, businessUsePercent: preliminary.businessUsePercent, taxYear: taxYear)
        return DeductionMethodCalculator.compare(trips: yearTrips, expenses: yearExpenses, phoneBusinessPercent: phoneBusinessPercent, depreciationDeduction: depreciation, recurringExpenses: recurringExpenses, taxYear: taxYear)
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
                    .accessibilityElement(children: .combine)
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
