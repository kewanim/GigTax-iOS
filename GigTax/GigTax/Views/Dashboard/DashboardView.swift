import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var payments: [QuarterlyPayment]

    @State private var taxYear = Calendar.current.component(.year, from: .now)
    @State private var methodOverride: DeductionMethod?
    @State private var explainedLine: WaterfallLine?

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let years = Set(shifts.map(\.taxYear)).union([currentYear])
        return years.sorted(by: >)
    }

    private var yearShifts: [Shift] { shifts.filter { $0.taxYear == taxYear } }

    private var comparison: (standard: TaxSummary, actual: TaxSummary, recommended: DeductionMethod) {
        TaxYearSummaryBuilder.compareBothMethods(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear)
    }

    private var selectedMethod: DeductionMethod {
        methodOverride ?? driverProfile?.preferredDeductionMethod ?? .standard
    }

    private var taxSummary: TaxSummary {
        selectedMethod == .standard ? comparison.standard : comparison.actual
    }

    private var yearPayments: [QuarterlyPayment] { payments.filter { $0.taxYear == taxYear } }
    private var paidSoFar: Double { yearPayments.reduce(0) { $0 + $1.amount } }

    private var remainingQuarters: [QuarterlyTaxCalculator.Quarter] {
        QuarterlyTaxCalculator.remainingQuarters(totalTaxOwed: taxSummary.totalTax, paidSoFar: paidSoFar, forYear: taxYear)
    }

    var body: some View {
        NavigationStack {
            Group {
                if yearShifts.isEmpty {
                    ContentUnavailableView(
                        "No earnings yet",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Import your earnings to get started.")
                    )
                } else {
                    List {
                        Section {
                            DashboardHeaderCard(taxSummary: taxSummary)
                        }

                        Section {
                            DeductionMethodToggleCard(
                                comparison: comparison,
                                selectedMethod: selectedMethod,
                                onSelect: { methodOverride = $0 }
                            )
                        }

                        Section {
                            ForEach(WaterfallLine.allCases) { line in
                                Button {
                                    explainedLine = line
                                } label: {
                                    WaterfallRow(line: line, taxSummary: taxSummary)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("Tax Breakdown")
                        } footer: {
                            Text("Tap any line for an explanation.")
                        }

                        if !remainingQuarters.isEmpty {
                            Section("Upcoming Quarterly Payments") {
                                ForEach(remainingQuarters, id: \.number) { quarter in
                                    HStack {
                                        Text("Q\(quarter.number)").fontWeight(.semibold)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(quarter.amountDue, format: .currency(code: "USD"))
                                            Text(quarter.dueDate, style: .date).font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Picker("Tax Year", selection: $taxYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                }
            }
            .alert(item: $explainedLine) { line in
                Alert(title: Text(line.title), message: Text(line.explanation(taxSummary: taxSummary)), dismissButton: .default(Text("Got it")))
            }
        }
    }
}

private enum WaterfallLine: String, CaseIterable, Identifiable {
    case gross, deductions, netProfit, selfEmploymentTax, federal, state, total

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gross: return "Gross Income"
        case .deductions: return "Business Deductions"
        case .netProfit: return "Net Profit"
        case .selfEmploymentTax: return "Self-Employment Tax"
        case .federal: return "Federal Tax"
        case .state: return "State & Local Tax"
        case .total: return "Total Tax Owed"
        }
    }

    func amount(_ taxSummary: TaxSummary) -> Double {
        switch self {
        case .gross: return taxSummary.grossIncome
        case .deductions: return -taxSummary.businessDeductions
        case .netProfit: return taxSummary.netProfit
        case .selfEmploymentTax: return taxSummary.selfEmploymentTax.total
        case .federal: return taxSummary.federalTax
        case .state: return taxSummary.stateTax
        case .total: return taxSummary.totalTax
        }
    }

    var isEmphasized: Bool { self == .netProfit || self == .total }

    func explanation(taxSummary: TaxSummary) -> String {
        switch self {
        case .gross:
            return "Total earnings from all logged shifts this tax year, before any deductions."
        case .deductions:
            return "Your business deductions — either standard mileage (business miles × $0.70) or actual vehicle + business expenses, whichever method is selected above."
        case .netProfit:
            return "Gross income minus business deductions. This is your Schedule C net profit — the amount self-employment and income tax are calculated from."
        case .selfEmploymentTax:
            let result = taxSummary.selfEmploymentTax
            return "12.4% Social Security + 2.9% Medicare on 92.35% of net profit. Social Security is capped at the annual wage base; Medicare is not. Half of this (\(result.halfDeduction.formatted(.currency(code: "USD")))) is deductible against your income tax."
        case .federal:
            return "Federal income tax on your taxable income (net profit minus half your SE tax minus the standard deduction), using this year's IRS brackets for your filing status."
        case .state:
            return "State income tax (plus county tax, if applicable) on the same taxable income as federal."
        case .total:
            return "Self-employment tax + federal tax + state tax. Effective rate: \((taxSummary.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))% of gross income. Marginal federal bracket: \((taxSummary.marginalRate * 100).formatted(.number.precision(.fractionLength(0))))%."
        }
    }
}

private struct DashboardHeaderCard: View {
    let taxSummary: TaxSummary

    private var netIncome: Double { taxSummary.grossIncome - taxSummary.totalTax }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                MetricColumn(title: "YTD Gross", value: taxSummary.grossIncome)
                Divider()
                MetricColumn(title: "YTD Net", value: netIncome)
                Divider()
                MetricColumn(title: "Tax Owed", value: taxSummary.totalTax)
            }
            HStack(spacing: 8) {
                RatePill(text: "Effective: \((taxSummary.effectiveRate * 100).formatted(.number.precision(.fractionLength(1))))%")
                RatePill(text: "Marginal: \(Int(taxSummary.marginalRate * 100))% bracket")
            }
        }
        .padding(.vertical, 8)
    }
}

private struct MetricColumn: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RatePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            .foregroundStyle(Color.accentColor)
    }
}

private struct WaterfallRow: View {
    let line: WaterfallLine
    let taxSummary: TaxSummary

    var body: some View {
        HStack {
            Text(line.title)
                .fontWeight(line.isEmphasized ? .semibold : .regular)
            Spacer()
            Text(line.amount(taxSummary), format: .currency(code: "USD"))
                .fontWeight(line.isEmphasized ? .semibold : .regular)
                .foregroundStyle(line.amount(taxSummary) < 0 ? .red : .primary)
        }
        .contentShape(Rectangle())
    }
}

private struct DeductionMethodToggleCard: View {
    let comparison: (standard: TaxSummary, actual: TaxSummary, recommended: DeductionMethod)
    let selectedMethod: DeductionMethod
    let onSelect: (DeductionMethod) -> Void

    private var savings: Double {
        abs(comparison.standard.totalTax - comparison.actual.totalTax)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Deduction Method", selection: Binding(
                get: { selectedMethod },
                set: { onSelect($0) }
            )) {
                Text("Standard Mileage").tag(DeductionMethod.standard)
                Text("Actual Expense").tag(DeductionMethod.actual)
            }
            .pickerStyle(.segmented)

            if savings > 0.5 {
                Text("\(comparison.recommended == .standard ? "Standard Mileage" : "Actual Expense") saves you \(savings.formatted(.currency(code: "USD"))) this year.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self, QuarterlyPayment.self], inMemory: true)
}
