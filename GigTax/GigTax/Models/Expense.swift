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

    /// Phone is typically shared between personal and business use; every
    /// other category is assumed fully deductible.
    func deductibleAmount(phoneBusinessPercent: Double) -> Double {
        category == .phone ? amount * (phoneBusinessPercent / 100) : amount
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

    /// Auto-creates a linked fuel expense from a completed trip's estimated
    /// cost, so every drive contributes to the driver's deductible fuel total
    /// without them having to log it by hand.
    static func fuelExpense(for trip: Trip) -> Expense? {
        guard trip.estimatedFuelCost > 0 else { return nil }
        let gallons = trip.estimatedFuelGallons
        let perGallon = gallons > 0 ? trip.estimatedFuelCost / gallons : 0
        let expense = Expense(
            date: trip.endDate ?? trip.startDate,
            category: .fuel,
            amount: trip.estimatedFuelCost,
            notes: String(format: "%.2f gal @ $%.2f/gal for %.1f mi trip", gallons, perGallon, trip.distanceMiles)
        )
        expense.linkedTripID = trip.id
        return expense
    }
}
