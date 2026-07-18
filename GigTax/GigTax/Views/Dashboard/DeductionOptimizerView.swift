import SwiftUI
import SwiftData
import Charts

struct DeductionOptimizerView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var vehicles: [Vehicle]
    @Query private var recurringExpenses: [RecurringExpense]

    let taxYear: Int

    private var driverProfile: DriverProfile? { driverProfiles.first }

    /// Deliberately excludes depreciation — this feeds the breakeven-mileage
    /// chart, which is specifically about vehicle *operating* costs
    /// (fuel/maintenance/insurance) vs. the standard rate, not the full
    /// actual-expense total. Recurring vehicle-cost-category expenses (e.g. a
    /// subscription car wash) are real operating costs too, so they're
    /// included the same as one-time logged ones.
    private var comparison: DeductionMethodCalculator.Comparison {
        DeductionMethodCalculator.compare(
            trips: trips.filter { $0.taxYear == taxYear },
            expenses: expenses.filter { $0.taxYear == taxYear },
            phoneBusinessPercent: driverProfile?.phoneBusinessPercent ?? 100,
            recurringExpenses: recurringExpenses,
            taxYear: taxYear
        )
    }

    private var taxComparison: (standard: TaxSummary, actual: TaxSummary, recommended: DeductionMethod) {
        TaxYearSummaryBuilder.compareBothMethods(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, vehicle: vehicles.first, recurringExpenses: recurringExpenses)
    }

    private var breakeven: BreakevenMileageCalculator.Result? {
        BreakevenMileageCalculator.calculate(comparison: comparison)
    }

    var body: some View {
        List {
            Section {
                RecommendationBanner(recommended: taxComparison.recommended, savings: abs(taxComparison.standard.totalTax - taxComparison.actual.totalTax))
            }

            Section("Side-by-Side Comparison") {
                MethodComparisonGrid(standard: taxComparison.standard, actual: taxComparison.actual, recommended: taxComparison.recommended)
            }

            if let breakeven {
                Section {
                    BreakevenChart(breakeven: breakeven, comparison: comparison)
                } header: {
                    Text("Breakeven Mileage")
                } footer: {
                    Text(breakeven.isCurrentlyAboveBreakeven
                        ? "You're above breakeven — standard mileage currently wins for your vehicle costs."
                        : "You're below breakeven — actual expenses currently win for your vehicle costs.")
                }
            }
        }
        .navigationTitle("Deduction Optimizer")
    }
}

private struct RecommendationBanner: View {
    let recommended: DeductionMethod
    let savings: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Recommended: \(recommended == .standard ? "Standard Mileage" : "Actual Expense")", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)
            if savings > 0.5 {
                Text("Saves you \(savings.formatted(.currency(code: "USD"))) in total tax this year compared to the other method.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Both methods produce almost identical tax this year.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MethodComparisonGrid: View {
    let standard: TaxSummary
    let actual: TaxSummary
    let recommended: DeductionMethod

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("").frame(width: 0)
                MethodHeader(title: "Standard", isRecommended: recommended == .standard)
                MethodHeader(title: "Actual", isRecommended: recommended == .actual)
            }
            GridRow {
                Text("Deductions").foregroundStyle(.secondary)
                Text(standard.businessDeductions, format: .currency(code: "USD"))
                Text(actual.businessDeductions, format: .currency(code: "USD"))
            }
            GridRow {
                Text("Taxable Income").foregroundStyle(.secondary)
                Text(standard.taxableIncome, format: .currency(code: "USD"))
                Text(actual.taxableIncome, format: .currency(code: "USD"))
            }
            GridRow {
                Text("Total Tax").foregroundStyle(.secondary)
                Text(standard.totalTax, format: .currency(code: "USD")).fontWeight(.semibold)
                Text(actual.totalTax, format: .currency(code: "USD")).fontWeight(.semibold)
            }
        }
        .font(.subheadline)
        .padding(.vertical, 4)
    }
}

private struct MethodHeader: View {
    let title: String
    let isRecommended: Bool

    var body: some View {
        HStack(spacing: 4) {
            Text(title).fontWeight(.bold)
            if isRecommended {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRecommended ? "\(title), recommended" : title)
    }
}

private struct BreakevenChart: View {
    let breakeven: BreakevenMileageCalculator.Result
    let comparison: DeductionMethodCalculator.Comparison

    private var maxMiles: Double {
        max(breakeven.breakevenMiles, breakeven.currentBusinessMiles) * 1.4
    }

    private var accessibilitySummary: String {
        let comparisonWord = breakeven.isCurrentlyAboveBreakeven ? "above" : "below"
        return "Breakeven at \(Int(breakeven.breakevenMiles)) business miles. You're currently at \(Int(breakeven.currentBusinessMiles)) miles, \(comparisonWord) breakeven."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Breakeven: \(Int(breakeven.breakevenMiles)) mi")
                Spacer()
                Text("You: \(Int(breakeven.currentBusinessMiles)) mi")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            Chart {
                LineMark(x: .value("Miles", 0), y: .value("Standard Deduction", 0))
                LineMark(x: .value("Miles", maxMiles), y: .value("Standard Deduction", maxMiles * 0.70))
                .foregroundStyle(by: .value("Series", "Standard Mileage"))

                RuleMark(y: .value("Actual", breakeven.actualVehicleDeduction))
                    .foregroundStyle(by: .value("Series", "Actual Expense"))
                    .lineStyle(StrokeStyle(dash: [4, 4]))

                RuleMark(x: .value("Breakeven", breakeven.breakevenMiles))
                    .foregroundStyle(.gray.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [2, 2]))

                PointMark(x: .value("Miles", breakeven.currentBusinessMiles), y: .value("Your deduction", breakeven.currentBusinessMiles * 0.70))
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(100)
            }
            .frame(height: 200)
            .accessibilityElement()
            .accessibilityLabel("Breakeven mileage chart")
            .accessibilityValue(accessibilitySummary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        DeductionOptimizerView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self], inMemory: true)
}
