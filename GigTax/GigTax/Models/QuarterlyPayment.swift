import Foundation
import SwiftData

@Model
final class QuarterlyPayment {
    var id: UUID
    var quarterNumber: Int  // 1-4
    var taxYear: Int
    var date: Date
    var amount: Double
    var confirmationNumber: String

    init(
        quarterNumber: Int,
        taxYear: Int,
        date: Date = .now,
        amount: Double = 0,
        confirmationNumber: String = ""
    ) {
        self.id = UUID()
        self.quarterNumber = quarterNumber
        self.taxYear = taxYear
        self.date = date
        self.amount = amount
        self.confirmationNumber = confirmationNumber
    }
}
