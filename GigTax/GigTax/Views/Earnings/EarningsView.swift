import SwiftUI
import SwiftData
import Charts

private enum EarningsPeriod: String, CaseIterable {
    case thisMonth = "Month"
    case last3Months = "3 Months"
    case thisYear = "Year"
    case allTime = "All"

    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .thisMonth:
            return calendar.isDate(date, equalTo: .now, toGranularity: .month)
        case .last3Months:
            guard let cutoff = calendar.date(byAdding: .month, value: -3, to: .now) else { return true }
            return date >= cutoff
        case .thisYear:
            return calendar.isDate(date, equalTo: .now, toGranularity: .year)
        case .allTime:
            return true
        }
    }
}

struct EarningsView: View {
    @Query(sort: \Shift.date, order: .reverse) private var shifts: [Shift]
    @State private var showImport = false
    @State private var showManualEntry = false
    @State private var period = EarningsPeriod.thisMonth

    private var periodShifts: [Shift] {
        shifts.filter { period.includes($0.date) }
    }

    private var platformTotals: [(platform: Platform, total: Double)] {
        Dictionary(grouping: periodShifts, by: \.platform)
            .map { (platform: $0.key, total: $0.value.reduce(0) { $0 + $1.totalIncome }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                if shifts.isEmpty {
                    ContentUnavailableView(
                        "No earnings yet",
                        systemImage: "dollarsign.circle",
                        description: Text("Import a CSV from your driver app or log a shift manually.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        Picker("Period", selection: $period) {
                            ForEach(EarningsPeriod.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)

                        if platformTotals.isEmpty {
                            Text("No earnings in this period.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(platformTotals, id: \.platform) { entry in
                                BarMark(
                                    x: .value("Earnings", entry.total),
                                    y: .value("Platform", entry.platform.rawValue)
                                )
                                .foregroundStyle(Color.accentColor)
                            }
                            .frame(height: CGFloat(platformTotals.count) * 36 + 20)
                        }
                    }

                    ForEach(groupedByMonth, id: \.month) { group in
                        Section(header: Text(group.month, format: .dateTime.month(.wide).year())) {
                            ForEach(group.shifts) { shift in
                                NavigationLink {
                                    ManualShiftEntryView(editing: shift)
                                } label: {
                                    ShiftRow(shift: shift)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Earnings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showImport = true } label: {
                            Label("Import CSV", systemImage: "square.and.arrow.down")
                        }
                        Button { showManualEntry = true } label: {
                            Label("Log Shift Manually", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addShiftMenu")
                }
            }
            .sheet(isPresented: $showImport) {
                EarningsImportView()
            }
            .sheet(isPresented: $showManualEntry) {
                ManualShiftEntryView()
            }
        }
    }

    private var groupedByMonth: [(month: Date, shifts: [Shift])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: shifts) { shift in
            calendar.date(from: calendar.dateComponents([.year, .month], from: shift.date)) ?? shift.date
        }
        return dict.keys.sorted(by: >).map { (month: $0, shifts: dict[$0]!) }
    }
}

private struct ShiftRow: View {
    let shift: Shift

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: shift.platform.icon).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(shift.platform.rawValue).font(.subheadline).fontWeight(.semibold)
                    if shift.importSource == "manual" {
                        Text("Manual").font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(.tertiary).clipShape(Capsule())
                    }
                }
                Text(shift.date, style: .date).font(.caption).foregroundStyle(.secondary)
                Text(breakdown).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text(shift.totalIncome, format: .currency(code: "USD"))
                .font(.subheadline).fontWeight(.semibold)
        }
        .padding(.vertical, 2)
    }

    private var breakdown: String {
        var parts = ["Gross \(shift.grossIncome.formatted(.currency(code: "USD")))"]
        if shift.tips > 0 { parts.append("Tips \(shift.tips.formatted(.currency(code: "USD")))") }
        if shift.bonuses > 0 { parts.append("Bonus \(shift.bonuses.formatted(.currency(code: "USD")))") }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    EarningsView()
        .modelContainer(for: Shift.self, inMemory: true)
}
