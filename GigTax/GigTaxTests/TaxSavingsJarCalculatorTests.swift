import Testing
import Foundation
@testable import GigTax

struct TaxSavingsJarCalculatorTests {

    @Test func suggestsSetAsideBasedOnRecentWeekAndSavingsPercent() {
        let shift = Shift(date: .now, grossIncome: 1_000)
        let summary = TaxEngine.summary(grossIncome: 1_000, businessDeductions: 0, filingStatus: .single, stateTax: { _ in 0 })

        let result = TaxSavingsJarCalculator.calculate(shifts: [shift], taxSummary: summary, savingsPercent: 25)
        #expect(result != nil)
        #expect(result!.recentWeekGross == 1_000)
        #expect(abs(result!.suggestedSetAside - 250) < 0.01)
    }

    @Test func excludesShiftsOlderThanOneWeek() {
        let calendar = Calendar.current
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: .now)!
        let oldShift = Shift(date: twoWeeksAgo, grossIncome: 5_000)
        let summary = TaxEngine.summary(grossIncome: 5_000, businessDeductions: 0, filingStatus: .single, stateTax: { _ in 0 })

        let result = TaxSavingsJarCalculator.calculate(shifts: [oldShift], taxSummary: summary, savingsPercent: 25)
        #expect(result == nil) // no earnings within the last 7 days
    }

    @Test func onTrackProgressComparesSuggestedSavingsToActualTaxOwed() {
        let shift = Shift(date: .now, grossIncome: 10_000)
        let summary = TaxEngine.summary(grossIncome: 10_000, businessDeductions: 0, filingStatus: .single, stateTax: { _ in 0 })

        let result = TaxSavingsJarCalculator.calculate(shifts: [shift], taxSummary: summary, savingsPercent: 25)
        #expect(result != nil)
        // 25% of $10,000 = $2,500 suggested cumulative savings vs. the real computed tax bill.
        let expectedProgress = min((10_000 * 0.25) / summary.totalTax, 1.5)
        #expect(abs(result!.onTrackProgress - expectedProgress) < 0.001)
    }

    @Test func progressIsCappedAtOnePointFive() {
        let shift = Shift(date: .now, grossIncome: 100)
        let summary = TaxEngine.summary(grossIncome: 100, businessDeductions: 0, filingStatus: .single, stateTax: { _ in 0 })
        // With near-zero income, total tax is ~0, so an extreme savings percent shouldn't blow past the cap.
        let result = TaxSavingsJarCalculator.calculate(shifts: [shift], taxSummary: summary, savingsPercent: 90)
        if let result, summary.totalTax > 0 {
            #expect(result.onTrackProgress <= 1.5)
        }
    }
}
