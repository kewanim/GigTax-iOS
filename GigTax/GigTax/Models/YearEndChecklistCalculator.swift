import Foundation

/// Surfaces the loose ends worth cleaning up before filing — untagged
/// trips, business trips missing a purpose, expenses without a receipt,
/// and a stale odometer confirmation. Meant to show up starting Q4, when
/// a driver is close enough to filing season that fixing gaps still
/// matters, but not so early that every minor gap nags all year.
enum YearEndChecklistCalculator {
    enum Severity {
        case warning
        case info
    }

    struct ChecklistItem: Identifiable {
        let id = UUID()
        let title: String
        let count: Int
        let severity: Severity
    }

    struct Checklist {
        let items: [ChecklistItem]
        var isEmpty: Bool { items.isEmpty }
    }

    static func isYearEndWindow(asOf date: Date = .now) -> Bool {
        Calendar.current.component(.month, from: date) >= 10  // Q4: Oct, Nov, Dec
    }

    static func generate(trips: [Trip], expenses: [Expense], vehicle: Vehicle?, taxYear: Int, asOf date: Date = .now) -> Checklist {
        var items: [ChecklistItem] = []

        let yearTrips = trips.filter { $0.taxYear == taxYear && $0.isComplete }

        let untaggedTrips = yearTrips.filter { $0.tripType == .unknown }
        if !untaggedTrips.isEmpty {
            items.append(ChecklistItem(title: "Untagged trips need a business or personal type", count: untaggedTrips.count, severity: .warning))
        }

        let missingPurposeTrips = yearTrips.filter { $0.tripType == .business && $0.businessPurpose.isEmpty }
        if !missingPurposeTrips.isEmpty {
            items.append(ChecklistItem(title: "Business trips missing a purpose", count: missingPurposeTrips.count, severity: .warning))
        }

        let yearExpenses = expenses.filter { $0.taxYear == taxYear }
        let unlinkedReceipts = yearExpenses.filter { $0.receiptImagePath == nil }
        if !unlinkedReceipts.isEmpty {
            items.append(ChecklistItem(title: "Expenses without a receipt attached", count: unlinkedReceipts.count, severity: .info))
        }

        if let vehicle {
            let daysSinceConfirmed = Calendar.current.dateComponents([.day], from: vehicle.lastConfirmedOdometerDate, to: date).day ?? 0
            if daysSinceConfirmed > 30 {
                items.append(ChecklistItem(title: "Odometer hasn't been confirmed in \(daysSinceConfirmed) days", count: 1, severity: .warning))
            }
        }

        return Checklist(items: items)
    }
}
