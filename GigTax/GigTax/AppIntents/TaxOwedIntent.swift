import AppIntents
import SwiftData
import SwiftUI
import Foundation

/// "How much do I owe in taxes?" — answers via Siri without needing to open
/// the app UI at all, using the same shared ModelContainer and
/// TaxYearSummaryBuilder the Dashboard itself uses, so the spoken answer
/// can never disagree with what the app shows on screen.
struct TaxOwedIntent: AppIntent {
    static var title: LocalizedStringResource = "How Much Do I Owe in Taxes?"
    static var description = IntentDescription("Returns your total estimated tax owed this year and the next quarterly payment amount.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let context = ModelContext(GigTaxModelContainer.shared)
        let shifts = try context.fetch(FetchDescriptor<Shift>())
        let trips = try context.fetch(FetchDescriptor<Trip>())
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let driverProfile = try context.fetch(FetchDescriptor<DriverProfile>()).first

        let taxYear = Calendar.current.component(.year, from: .now)
        let summary = TaxYearSummaryBuilder.build(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear)
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: summary.totalTax, forYear: taxYear)
        let nextQuarter = quarters.first { $0.dueDate > .now }

        var dialogText = "You owe an estimated \(summary.totalTax.formatted(.currency(code: "USD"))) in taxes for \(String(taxYear))."
        if let nextQuarter {
            dialogText += " Your next quarterly payment of \(nextQuarter.amountDue.formatted(.currency(code: "USD"))) is due \(nextQuarter.dueDate.formatted(date: .abbreviated, time: .omitted))."
        }

        return .result(
            dialog: IntentDialog(stringLiteral: dialogText),
            view: TaxOwedSnippetView(totalTax: summary.totalTax, taxYear: taxYear, nextQuarter: nextQuarter)
        )
    }
}

struct TaxOwedSnippetView: View {
    let totalTax: Double
    let taxYear: Int
    let nextQuarter: QuarterlyTaxCalculator.Quarter?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Estimated Tax Owed — \(String(taxYear))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(totalTax, format: .currency(code: "USD"))
                .font(.title2)
                .fontWeight(.bold)
            if let nextQuarter {
                Divider()
                HStack {
                    Text("Next: Q\(nextQuarter.number)")
                    Spacer()
                    Text(nextQuarter.amountDue, format: .currency(code: "USD"))
                    Text(nextQuarter.dueDate, style: .date)
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
        .padding()
    }
}
