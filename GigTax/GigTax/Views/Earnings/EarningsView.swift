import SwiftUI
import SwiftData

struct EarningsView: View {
    @Query(sort: \Shift.date, order: .reverse) private var shifts: [Shift]
    @State private var showImport = false
    @State private var showManualEntry = false

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
                    ForEach(groupedByMonth, id: \.month) { group in
                        Section(header: Text(group.month, format: .dateTime.month(.wide).year())) {
                            ForEach(group.shifts) { shift in
                                ShiftRow(shift: shift)
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
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(shift.totalIncome, format: .currency(code: "USD"))
                    .font(.subheadline).fontWeight(.semibold)
                if shift.tips > 0 {
                    Text("+\(shift.tips.formatted(.currency(code: "USD"))) tips")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    EarningsView()
        .modelContainer(for: Shift.self, inMemory: true)
}
