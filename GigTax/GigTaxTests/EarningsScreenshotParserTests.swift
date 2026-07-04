import Testing
import Foundation
@testable import GigTax

struct EarningsScreenshotParserTests {

    // Actual Vision OCR output (top-to-bottom by bounding box) from a real
    // Lyft "Weekly breakdown" screenshot — captured directly via a diagnostic
    // script against the source image, not hand-approximated. Note the
    // dollar amount frequently reads *before* its label line, since it's
    // right-aligned next to a left-aligned (sometimes wrapped) label.
    private let lyftLines = [
        "80", "10:201", "Weekly breakdown", "<",
        "Jun 22 - Jun 28",
        "$112.07",
        "8", "4 hr 11 min", "54.06 mi", "rides", "booked", "booked",
        "$25.97 per booked hr",
        "Excluding tips",
        "Earnings summary",
        "$163.36 0", "Passenger payments",
        "-$39.41", "Est. Lyft fee",
        "-$22.03 0", "Est. insurance, taxes,", "gov't fees",
        "$3.39 V", "Tips", "V",
        "$6.76", "Tolls & other pass-throughs",
        "$112.07 V", "Total earnings",
        "Track the Lyft fee for June",
        "The Lyft fee is capped at 30% of passenger",
        "payments each month. It was below the cap in",
        "June.",
        "Tap to track →",
    ]

    // Actual Vision OCR output from the real Uber "Customer fare breakdown"
    // screenshot that shows "Your earnings" and the date range together.
    private let uberLines = [
        "80", "10:19 4", "Customer fare breakdown",
        "Jun 22 - Jun 29",
        "Total: $1,465", "• You: 56%", "• Uber: 27%",
        "$816.81", "Your earnings", "56% 0",
        "Excludes tips of $79.55",
        "+$90.08", "Government taxes, third-", "6% 0", "party fees, and regulatory-", "related charges",
        "Estimated commercial auto", "$0.00", "0% •", "insurance and operational", "expenses",
        "Estimated commercial", "+$135.25", "auto insurance and", "9% 0", "operational expenses",
        "+$22.95", "Customer promotions", "2% •",
        "+$399.74", "Iher Service Fee",
        "Menu", "Home", "Discover", "Inbox", "Earnings",
    ]

    @Test func detectsLyftPlatform() {
        let result = EarningsScreenshotParser.parse(lines: lyftLines)
        #expect(result.platform == .lyft)
    }

    @Test func detectsUberPlatform() {
        let result = EarningsScreenshotParser.parse(lines: uberLines)
        #expect(result.platform == .uber)
    }

    @Test func lyftGrossIncomeExcludesTipsToAvoidDoubleCounting() {
        let result = EarningsScreenshotParser.parse(lines: lyftLines)
        // Total earnings $112.07 already includes tips $3.39 — gross should
        // be the total minus tips, so gross + tips reconstructs to $112.07.
        #expect(result.tips != nil)
        #expect(abs(result.tips! - 3.39) < 0.01)
        #expect(result.grossIncome != nil)
        #expect(abs(result.grossIncome! - (112.07 - 3.39)) < 0.01)
    }

    @Test func uberGrossIncomeAlreadyExcludesTips() {
        let result = EarningsScreenshotParser.parse(lines: uberLines)
        #expect(result.grossIncome != nil)
        #expect(abs(result.grossIncome! - 816.81) < 0.01)
        #expect(result.tips != nil)
        #expect(abs(result.tips! - 79.55) < 0.01)
    }

    @Test func parsesLyftDateRangeWithinSameMonth() {
        let result = EarningsScreenshotParser.parse(lines: lyftLines)
        #expect(result.startDate != nil)
        #expect(result.endDate != nil)
        let calendar = Calendar.current
        #expect(calendar.component(.month, from: result.startDate!) == 6)
        #expect(calendar.component(.day, from: result.startDate!) == 22)
        #expect(calendar.component(.day, from: result.endDate!) == 28)
    }

    @Test func parsesLyftMileage() {
        let result = EarningsScreenshotParser.parse(lines: lyftLines)
        #expect(result.miles != nil)
        #expect(abs(result.miles! - 54.06) < 0.01)
    }

    @Test func parsesLyftHoursWorkedFromHourMinuteFormat() {
        let result = EarningsScreenshotParser.parse(lines: lyftLines)
        #expect(result.hoursWorked != nil)
        // 4 hr 11 min = 4 + 11/60
        #expect(abs(result.hoursWorked! - (4 + 11.0 / 60.0)) < 0.01)
    }

    @Test func emptyInputProducesAllNilFields() {
        let result = EarningsScreenshotParser.parse(lines: [])
        #expect(result.platform == nil)
        #expect(result.grossIncome == nil)
        #expect(result.tips == nil)
        #expect(result.miles == nil)
        #expect(result.hoursWorked == nil)
        #expect(result.startDate == nil)
    }

    @Test func labelAndValueSplitAcrossSeparateLinesStillParses() {
        // OCR frequently splits a label and its dollar value into separate
        // text observations rather than one line — confirm the "search next
        // couple lines" fallback handles this (already exercised by the
        // Lyft/Uber fixtures above, but test it explicitly and minimally).
        let lines = ["Total earnings", "$50.00"]
        let result = EarningsScreenshotParser.parse(lines: lines)
        #expect(result.grossIncome != nil)
        #expect(abs(result.grossIncome! - 50.00) < 0.01)
    }
}
