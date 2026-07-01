import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID
    var date: Date
    var categoryRaw: String
    var amount: Double
    var notes: String
    var isRecurring: Bool
    var receiptImagePath: String?      // relative path in app sandbox
    var linkedTripID: UUID?            // auto-linked when generated from a trip
    var taxYear: Int

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        date: Date = .now,
        category: ExpenseCategory = .other,
        amount: Double = 0,
        notes: String = "",
        isRecurring: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.notes = notes
        self.isRecurring = isRecurring
        self.taxYear = Calendar.current.component(.year, from: date)
    }
}
