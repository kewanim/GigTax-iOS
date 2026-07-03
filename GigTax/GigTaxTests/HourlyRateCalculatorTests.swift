import Testing
import Foundation
@testable import GigTax

struct HourlyRateCalculatorTests {

    private func makeSummary(gross: Double, totalTaxImplied: Double) -> TaxSummary {
        // Use a filing status / state combo that produces a predictable,
        // easy-to-reason-about tax rather than asserting on real bracket math here.
        TaxEngine.summary(grossIncome: gross, businessDeductions: 0, filingStatus: .single, stateTax: { _ in 0 })
    }

    @Test func computesGrossAndNetPerHour() {
        let shift = Shift(date: .now, grossIncome: 1_000, hoursWorked: 10)
        let summary = makeSummary(gross: 1_000, totalTaxImplied: 0)

        let result = HourlyRateCalculator.calculate(shifts: [shift], taxSummary: summary)
        #expect(result != nil)
        #expect(result!.totalHours == 10)
        #expect(abs(result!.grossPerHour - 100) < 0.01)
        #expect(result!.netPerHour < result!.grossPerHour) // tax always brings net below gross when tax > 0
    }

    @Test func zeroHoursReturnsNil() {
        let shift = Shift(date: .now, grossIncome: 1_000, hoursWorked: 0)
        let summary = makeSummary(gross: 1_000, totalTaxImplied: 0)
        #expect(HourlyRateCalculator.calculate(shifts: [shift], taxSummary: summary) == nil)
    }

    @Test func sumsHoursAcrossMultipleShifts() {
        let shift1 = Shift(date: .now, grossIncome: 500, hoursWorked: 5)
        let shift2 = Shift(date: .now, grossIncome: 500, hoursWorked: 5)
        let summary = makeSummary(gross: 1_000, totalTaxImplied: 0)

        let result = HourlyRateCalculator.calculate(shifts: [shift1, shift2], taxSummary: summary)
        #expect(result?.totalHours == 10)
    }
}
