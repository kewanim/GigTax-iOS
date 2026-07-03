import Foundation
import SwiftData

enum RecurringFrequency: String, CaseIterable, Codable {
    case monthly = "Monthly"
    case yearly = "Yearly"
}

@Model
final class RecurringExpense {
    var id: UUID
    var categoryRaw: String
    var amount: Double
    var frequencyRaw: String
    var startDate: Date
    var isActive: Bool

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .monthly }
        set { frequencyRaw = newValue.rawValue }
    }

    var annualEquivalent: Double {
        frequency == .monthly ? amount * 12 : amount
    }

    /// Pro-rated total for the current tax year, counting only days since
    /// whichever is later: Jan 1 or this recurring expense's start date.
    var proRatedTotalToDate: Double {
        guard isActive else { return 0 }
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
        let effectiveStart = max(startOfYear, startDate)
        guard effectiveStart <= now else { return 0 }
        let daysElapsed = calendar.dateComponents([.day], from: effectiveStart, to: now).day ?? 0
        return annualEquivalent * (Double(daysElapsed) / 365.0)
    }

    init(
        category: ExpenseCategory = .other,
        amount: Double = 0,
        frequency: RecurringFrequency = .monthly,
        startDate: Date = .now,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.isActive = isActive
    }
}
