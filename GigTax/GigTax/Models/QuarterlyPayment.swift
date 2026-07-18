import Foundation
import SwiftData

@Model
final class QuarterlyPayment {
    // Every stored property below needs an inline default (not just one set in
    // init) — CloudKit's schema validation rejects any non-optional attribute
    // without one, and real values are always overwritten by init() anyway.
    var id: UUID = UUID()
    var quarterNumber: Int = 1  // 1-4
    var taxYear: Int = Calendar.current.component(.year, from: .now)
    var date: Date = Date.now
    var amount: Double = 0
    var confirmationNumber: String = ""

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
