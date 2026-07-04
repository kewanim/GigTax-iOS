import WidgetKit
import SwiftUI
import SwiftData

struct TodayEarningsEntry: TimelineEntry {
    let date: Date
    let todayGross: Double
    let todayMiles: Double
}

struct TodayEarningsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEarningsEntry {
        TodayEarningsEntry(date: .now, todayGross: 120, todayMiles: 42)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEarningsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEarningsEntry>) -> Void) {
        let entry = currentEntry()
        // AC: updates every 30 minutes.
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> TodayEarningsEntry {
        let context = ModelContext(GigTaxModelContainer.shared)
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)

        let allShifts = (try? context.fetch(FetchDescriptor<Shift>())) ?? []
        let todayShifts = allShifts.filter { $0.date >= startOfToday }
        let todayGross = todayShifts.reduce(0) { $0 + $1.totalIncome }

        let allTrips = (try? context.fetch(FetchDescriptor<Trip>())) ?? []
        let todayMiles = allTrips
            .filter { $0.isComplete && $0.startDate >= startOfToday }
            .reduce(0) { $0 + $1.distanceMiles }

        return TodayEarningsEntry(date: .now, todayGross: todayGross, todayMiles: todayMiles)
    }
}

struct TodayEarningsWidgetView: View {
    let entry: TodayEarningsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.todayGross, format: .currency(code: "USD"))
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Label("\(Int(entry.todayMiles)) mi", systemImage: "car.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

struct TodayEarningsWidget: Widget {
    let kind = "TodayEarningsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayEarningsProvider()) { entry in
            TodayEarningsWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Earnings")
        .description("Shows today's gross earnings and miles driven.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    TodayEarningsWidget()
} timeline: {
    TodayEarningsEntry(date: .now, todayGross: 120, todayMiles: 42)
}
