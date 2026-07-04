import Testing
import Foundation
@testable import GigTax

struct QuarterlyNotificationSchedulerTests {

    @Test func buildsTwoNotificationsPerFutureQuarter() {
        let year = 2025
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 4_000, forYear: year)
        // "asOf" well before any due date so all 4 quarters are still upcoming.
        let asOf = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!

        let notifications = QuarterlyNotificationScheduler.buildNotifications(for: quarters, taxYear: year, asOf: asOf)
        #expect(notifications.count == 8) // 4 quarters × (7-day reminder + due-today)
    }

    @Test func skipsPastReminderDatesButKeepsFutureDueDate() {
        let year = 2025
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 4_000, forYear: year)
        // 3 days before Q1's due date (Apr 15): the 7-day-before reminder has
        // already passed, but the due-today notification is still ahead.
        let asOf = Calendar.current.date(from: DateComponents(year: year, month: 4, day: 12))!

        let notifications = QuarterlyNotificationScheduler.buildNotifications(for: quarters, taxYear: year, asOf: asOf)
        let q1Notifications = notifications.filter { $0.identifier.contains("Q1") }
        #expect(q1Notifications.count == 1)
        #expect(q1Notifications[0].identifier.contains("dueToday"))
    }

    @Test func skipsQuartersEntirelyInThePast() {
        let year = 2025
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 4_000, forYear: year)
        // Well after Q1's due date — neither Q1 notification should appear.
        let asOf = Calendar.current.date(from: DateComponents(year: year, month: 5, day: 1))!

        let notifications = QuarterlyNotificationScheduler.buildNotifications(for: quarters, taxYear: year, asOf: asOf)
        #expect(!notifications.contains { $0.identifier.contains("Q1") })
    }

    @Test func notificationBodyIncludesFormattedAmount() {
        let year = 2025
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 4_000, forYear: year)
        let asOf = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!

        let notifications = QuarterlyNotificationScheduler.buildNotifications(for: quarters, taxYear: year, asOf: asOf)
        #expect(notifications.allSatisfy { $0.body.contains("$1,000") }) // $4,000 / 4 quarters
    }

    @Test func identifiersAreUniquePerQuarterAndTiming() {
        let year = 2025
        let quarters = QuarterlyTaxCalculator.quarters(totalTaxOwed: 4_000, forYear: year)
        let asOf = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!

        let notifications = QuarterlyNotificationScheduler.buildNotifications(for: quarters, taxYear: year, asOf: asOf)
        let identifiers = Set(notifications.map(\.identifier))
        #expect(identifiers.count == notifications.count) // no duplicates
    }
}
