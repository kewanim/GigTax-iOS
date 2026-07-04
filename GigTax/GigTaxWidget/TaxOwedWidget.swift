import WidgetKit
import SwiftUI
import SwiftData

struct TaxOwedEntry: TimelineEntry {
    let date: Date
    let totalTax: Double
    let nextQuarterNumber: Int?
    let nextQuarterAmount: Double?
    let nextQuarterDueDate: Date?
}

struct TaxOwedProvider: TimelineProvider {
    func placeholder(in context: Context) -> TaxOwedEntry {
        TaxOwedEntry(date: .now, totalTax: 4500, nextQuarterNumber: 3, nextQuarterAmount: 1125, nextQuarterDueDate: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (TaxOwedEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TaxOwedEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> TaxOwedEntry {
        let context = ModelContext(GigTaxModelContainer.shared)
        let shifts = (try? context.fetch(FetchDescriptor<Shift>())) ?? []
        let trips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let driverProfile = (try? context.fetch(FetchDescriptor<DriverProfile>()))?.first

        let taxYear = Calendar.current.component(.year, from: .now)
        let summary = TaxYearSummaryBuilder.build(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear)
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: summary.totalTax, forYear: taxYear)
        let nextQuarter = quarters.first { $0.dueDate > .now }

        return TaxOwedEntry(
            date: .now,
            totalTax: summary.totalTax,
            nextQuarterNumber: nextQuarter?.number,
            nextQuarterAmount: nextQuarter?.amountDue,
            nextQuarterDueDate: nextQuarter?.dueDate
        )
    }
}

struct TaxOwedWidgetView: View {
    let entry: TaxOwedEntry

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("YTD Tax Owed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(entry.totalTax, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                if let number = entry.nextQuarterNumber, let amount = entry.nextQuarterAmount, let dueDate = entry.nextQuarterDueDate {
                    Text("Next: Q\(number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(amount, format: .currency(code: "USD"))
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(dueDate, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No upcoming payment")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TaxOwedWidget: Widget {
    let kind = "TaxOwedWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TaxOwedProvider()) { entry in
            TaxOwedWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "gigtax://dashboard"))
        }
        .configurationDisplayName("Tax Owed")
        .description("Shows your YTD estimated tax owed and next quarterly due date.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    TaxOwedWidget()
} timeline: {
    TaxOwedEntry(date: .now, totalTax: 4500, nextQuarterNumber: 3, nextQuarterAmount: 1125, nextQuarterDueDate: .now)
}
