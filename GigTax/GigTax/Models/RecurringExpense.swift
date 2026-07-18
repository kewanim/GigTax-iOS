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
    var endDate: Date?  // nil = still active/ongoing; set when a driver stops paying for something mid-year
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

    /// Pro-rated total for a given tax year, bounded to whichever is later of
    /// Jan 1 or this expense's start date, and whichever is earlier of Dec 31,
    /// this expense's end date (if it's since stopped), or today (if this is
    /// the current, still-unfolding year). A fully past year with no end date
    /// gets the full annual equivalent; a future year gets 0 (hasn't happened
    /// yet, and the driver's year picker shouldn't ever offer one, but this
    /// guards against it regardless).
    ///
    /// Deliberately does NOT gate on `isActive` — that reflects today's
    /// on/off state, not history, so it can't be trusted to tell you whether
    /// this was running in a given past year. Pausing sets `endDate` to the
    /// pause date (see RecurringExpenseEntryView), which is what actually
    /// keeps past totals accurate, matching the driver-facing promise that
    /// pausing (vs. deleting) preserves history.
    func proRatedTotal(forTaxYear taxYear: Int) -> Double {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        guard taxYear <= currentYear else { return 0 }
        guard let startOfYear = calendar.date(from: DateComponents(year: taxYear, month: 1, day: 1)),
              let startOfNextYear = calendar.date(from: DateComponents(year: taxYear + 1, month: 1, day: 1)) else { return 0 }

        let periodEnd = min(endDate ?? .distantFuture, startOfNextYear, taxYear == currentYear ? .now : startOfNextYear)
        let periodStart = max(startOfYear, startDate)
        guard periodStart < periodEnd else { return 0 }

        let daysElapsed = calendar.dateComponents([.day], from: periodStart, to: periodEnd).day ?? 0
        return annualEquivalent * (Double(daysElapsed) / 365.0)
    }

    /// Phone is typically shared between personal and business use, mirroring
    /// Expense.deductibleAmount(phoneBusinessPercent:) — every other category
    /// is assumed fully deductible.
    func deductibleAmount(phoneBusinessPercent: Double, forTaxYear taxYear: Int) -> Double {
        let total = proRatedTotal(forTaxYear: taxYear)
        return category == .phone ? total * (phoneBusinessPercent / 100) : total
    }

    init(
        category: ExpenseCategory = .other,
        amount: Double = 0,
        frequency: RecurringFrequency = .monthly,
        startDate: Date = .now,
        endDate: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
    }
}
