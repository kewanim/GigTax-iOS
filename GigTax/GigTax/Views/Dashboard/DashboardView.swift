import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var payments: [QuarterlyPayment]
    @Query private var vehicles: [Vehicle]

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
        TaxYearSummaryBuilder.compareBothMethods(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, vehicle: vehicles.first)
    }

    private var selectedMethod: DeductionMethod {
        methodOverride ?? driverProfile?.preferredDeductionMethod ?? .standard
    }

    private var taxSummary: TaxSummary {
        selectedMethod == .standard ? comparison.standard : comparison.actual
    }

    private var yearPayments: [QuarterlyPayment] { payments.filter { $0.taxYear == taxYear } }

    private var quarterStatuses: [QuarterStatus] {
        QuarterlyTaxCalculator.quarters(totalTaxOwed: taxSummary.totalTax, forYear: taxYear).map { quarter in
            let paid = yearPayments.filter { $0.quarterNumber == quarter.number }.reduce(0) { $0 + $1.amount }
            return QuarterStatus(quarter: quarter, paid: paid)
        }
    }

    private var monthlyTotals: [MonthlyEarningsCalculator.MonthlyPlatformTotal] {
        MonthlyEarningsCalculator.monthlyTotals(shifts: shifts, taxYear: taxYear)
    }

    private var mileageComparison: MileageComparisonCalculator.Comparison {
        MileageComparisonCalculator.compare(trips: trips.filter { $0.taxYear == taxYear }, shifts: yearShifts)
    }

    private var hourlyRate: HourlyRateCalculator.Result? {
        HourlyRateCalculator.calculate(shifts: yearShifts, taxSummary: taxSummary)
    }

    private var platformRates: [PlatformProfitabilityCalculator.PlatformRate] {
        PlatformProfitabilityCalculator.rank(shifts: yearShifts, effectiveTaxRate: taxSummary.effectiveRate)
    }

    private var savingsRecommendation: TaxSavingsJarCalculator.Recommendation? {
        TaxSavingsJarCalculator.calculate(shifts: yearShifts, taxSummary: taxSummary, savingsPercent: driverProfile?.taxSavingsPercent ?? 25)
    }

    private var earningsInsights: EarningsPatternAnalyzer.Insights? {
        EarningsPatternAnalyzer.analyze(shifts: yearShifts)
    }

    private var yearEndChecklist: YearEndChecklistCalculator.Checklist {
        YearEndChecklistCalculator.generate(trips: trips, expenses: expenses, vehicle: vehicles.first, taxYear: taxYear)
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

                        if YearEndChecklistCalculator.isYearEndWindow(), !yearEndChecklist.isEmpty {
                            Section("Year-End Checklist") {
                                ForEach(yearEndChecklist.items) { item in
                                    YearEndChecklistRow(item: item)
                                }
                            }
                        }

                        Section {
                            DeductionMethodToggleCard(
                                comparison: comparison,
                                selectedMethod: selectedMethod,
                                onSelect: { methodOverride = $0 }
                            )
                            NavigationLink("View Full Comparison") {
                                DeductionOptimizerView(taxYear: taxYear)
                            }
                            NavigationLink("Schedule C Summary") {
                                ScheduleCSummaryView(taxYear: taxYear)
                            }
                            NavigationLink("What If I Drove More?") {
                                WhatIfSimulatorView(taxYear: taxYear)
                            }
                            NavigationLink("Vehicle Depreciation") {
                                VehicleDepreciationView(taxYear: taxYear)
                            }
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

                        Section("Quarterly Payments") {
                            QuarterlyPaymentGrid(quarterStatuses: quarterStatuses)
                        }

                        Section("Monthly Earnings") {
                            MonthlyEarningsChart(totals: monthlyTotals)
                        }

                        if mileageComparison.gpsMiles > 0 || mileageComparison.reportedMiles > 0 {
                            Section {
                                MileageComparisonCard(comparison: mileageComparison)
                            } header: {
                                Text("Mileage: App vs. Platform")
                            } footer: {
                                Text("Deadhead and positioning miles the platform doesn't report still count toward your deduction.")
                            }
                        }

                        if let hourlyRate {
                            Section("Net Hourly Rate") {
                                HourlyRateRow(hourlyRate: hourlyRate)
                            }
                        }

                        if platformRates.count > 1 {
                            Section("Platform Profitability") {
                                ForEach(platformRates) { rate in
                                    PlatformRateRow(rate: rate)
                                }
                            }
                        }

                        if let savingsRecommendation {
                            Section {
                                TaxSavingsJarCard(recommendation: savingsRecommendation)
                            } header: {
                                Text("Tax Savings Jar")
                            }
                        }

                        if let earningsInsights {
                            Section("Your Earnings Patterns") {
                                EarningsInsightsCard(insights: earningsInsights)
                            }
                        }
                    }
                    .task(id: taxSummary.totalTax) {
                        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: taxSummary.totalTax, forYear: taxYear)
                        await QuarterlyNotificationScheduler.scheduleAll(for: quarters, taxYear: taxYear, enabled: driverProfile?.notificationsEnabled ?? true)
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
        .accessibilityElement(children: .combine)
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

private struct QuarterStatus: Identifiable {
    let quarter: QuarterlyTaxCalculator.Quarter
    let paid: Double

    var id: Int { quarter.number }
    var isPaidInFull: Bool { paid >= quarter.amountDue - 0.5 }
    var isPastDue: Bool { !isPaidInFull && quarter.dueDate < .now }
}

private struct QuarterlyPaymentGrid: View {
    let quarterStatuses: [QuarterStatus]

    private var nextUpcomingQuarterNumber: Int? {
        quarterStatuses.first { !$0.isPaidInFull && $0.quarter.dueDate >= .now }?.quarter.number
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(quarterStatuses) { status in
                QuarterCard(status: status, isNextUpcoming: status.quarter.number == nextUpcomingQuarterNumber)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct QuarterCard: View {
    let status: QuarterStatus
    let isNextUpcoming: Bool

    private var borderColor: Color {
        if status.isPastDue { return .red }
        if isNextUpcoming { return .accentColor }
        return .clear
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Q\(status.quarter.number)").fontWeight(.bold)
                Spacer()
                if status.isPaidInFull {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if status.isPastDue {
                    Text("PAST DUE").font(.caption2).fontWeight(.bold).foregroundStyle(.red)
                } else if isNextUpcoming {
                    Text("NEXT").font(.caption2).fontWeight(.bold).foregroundStyle(Color.accentColor)
                }
            }
            Text(status.quarter.amountDue, format: .currency(code: "USD"))
                .font(.headline)
                .foregroundStyle(status.isPastDue ? .red : .primary)
            Text(status.quarter.dueDate, style: .date)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemGroupedBackground)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 2))
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap for an explanation")
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

private struct MonthlyEarningsChart: View {
    let totals: [MonthlyEarningsCalculator.MonthlyPlatformTotal]

    private var isSinglePlatform: Bool {
        MonthlyEarningsCalculator.distinctPlatforms(in: totals).count <= 1
    }

    private func monthLabel(_ month: Int) -> String {
        MonthlyEarningsCalculator.monthSymbols[month - 1]
    }

    private var accessibilitySummary: String {
        let monthlyTotals = Dictionary(grouping: totals, by: \.month)
            .map { (month: $0.key, total: $0.value.reduce(0) { $0 + $1.total }) }
            .sorted { $0.month < $1.month }
        return monthlyTotals
            .map { "\(monthLabel($0.month)): \($0.total.formatted(.currency(code: "USD")))" }
            .joined(separator: ", ")
    }

    var body: some View {
        if totals.isEmpty {
            Text("No earnings logged this year yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Chart(totals) { entry in
                if isSinglePlatform {
                    BarMark(
                        x: .value("Month", monthLabel(entry.month)),
                        y: .value("Earnings", entry.total)
                    )
                    .foregroundStyle(Color.accentColor)
                } else {
                    BarMark(
                        x: .value("Month", monthLabel(entry.month)),
                        y: .value("Earnings", entry.total)
                    )
                    .foregroundStyle(by: .value("Platform", entry.platform.rawValue))
                }
            }
            .frame(height: 220)
            .padding(.vertical, 4)
            .accessibilityElement()
            .accessibilityLabel("Monthly earnings this year")
            .accessibilityValue(accessibilitySummary)
        }
    }
}

private struct MileageComparisonCard: View {
    let comparison: MileageComparisonCalculator.Comparison

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App (GPS)").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(comparison.gpsMiles)) mi").font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Platform Reported").font(.caption).foregroundStyle(.secondary)
                    Text("\(Int(comparison.reportedMiles)) mi").font(.headline)
                }
            }
            if comparison.extraMiles > 0 {
                Divider()
                HStack {
                    Text("Extra miles caught")
                    Spacer()
                    Text("+\(Int(comparison.extraMiles)) mi (\(comparison.extraDollarsRecovered.formatted(.currency(code: "USD"))))")
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct HourlyRateRow: View {
    let hourlyRate: HourlyRateCalculator.Result

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gross/hr").font(.caption).foregroundStyle(.secondary)
                Text(hourlyRate.grossPerHour, format: .currency(code: "USD")).font(.headline)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Net/hr").font(.caption).foregroundStyle(.secondary)
                Text(hourlyRate.netPerHour, format: .currency(code: "USD")).font(.headline)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct PlatformRateRow: View {
    let rate: PlatformProfitabilityCalculator.PlatformRate

    var body: some View {
        HStack {
            Text(rate.platform.rawValue)
            Spacer()
            Text("\(rate.netPerHour.formatted(.currency(code: "USD")))/hr net")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TaxSavingsJarCard: View {
    let recommendation: TaxSavingsJarCalculator.Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set aside \(recommendation.suggestedSetAside.formatted(.currency(code: "USD"))) (\(Int(recommendation.savingsPercent))%) from this week's \(recommendation.recentWeekGross.formatted(.currency(code: "USD"))) earnings.")
                .font(.subheadline)

            ProgressView(value: min(recommendation.onTrackProgress, 1.0)) {
                Text("On track for this year's tax bill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .tint(recommendation.onTrackProgress >= 1.0 ? .green : .orange)
        }
        .padding(.vertical, 4)
    }
}

private struct EarningsInsightsCard: View {
    let insights: EarningsPatternAnalyzer.Insights

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar").foregroundStyle(.secondary).accessibilityHidden(true)
                Text("Best day: **\(insights.bestDayOfWeek)** (avg \(insights.bestDayAverage.formatted(.currency(code: "USD"))))")
            }
            .accessibilityElement(children: .combine)
            HStack {
                Image(systemName: "trophy").foregroundStyle(.secondary).accessibilityHidden(true)
                Text("Best platform: **\(insights.bestPlatform.rawValue)** (\(insights.bestPlatformTotal.formatted(.currency(code: "USD"))) total)")
            }
            .accessibilityElement(children: .combine)
        }
        .font(.subheadline)
        .padding(.vertical, 2)
    }
}

private struct YearEndChecklistRow: View {
    let item: YearEndChecklistCalculator.ChecklistItem

    var body: some View {
        HStack {
            Image(systemName: item.severity == .warning ? "exclamationmark.triangle.fill" : "info.circle")
                .foregroundStyle(item.severity == .warning ? .orange : .secondary)
            Text(item.title)
            Spacer()
            Text("\(item.count)")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self, QuarterlyPayment.self, Vehicle.self], inMemory: true)
}
