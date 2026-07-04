import Testing
import Foundation
@testable import GigTax

struct WhatIfSimulatorTests {

    @Test func extraDeductionEqualsExtraMilesTimesStandardRate() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let year = Calendar.current.component(.year, from: .now)

        let result = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 500)
        #expect(abs(result.extraDeduction - 350) < 0.01) // 500 × $0.70
    }

    @Test func moreMilesProducesMoreTaxSavings() {
        let shift = Shift(date: .now, grossIncome: 80_000)
        let year = Calendar.current.component(.year, from: .now)

        let small = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 100)
        let large = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 1_000)
        #expect(large.taxSavings > small.taxSavings)
    }

    @Test func zeroExtraMilesProducesZeroSavings() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let year = Calendar.current.component(.year, from: .now)

        let result = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 0)
        #expect(result.taxSavings == 0)
        #expect(result.netIncomeDelta == 0)
    }

    @Test func netIncomeDeltaEqualsTaxSavings() {
        let shift = Shift(date: .now, grossIncome: 60_000)
        let year = Calendar.current.component(.year, from: .now)

        let result = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 300)
        #expect(result.netIncomeDelta == result.taxSavings)
    }

    @Test func negativeExtraMilesDoesNotReduceDeductionBelowBaseline() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let year = Calendar.current.component(.year, from: .now)

        let result = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: -500)
        #expect(result.extraDeduction == 0)
        #expect(result.taxSavings == 0)
    }

    @Test func accountsForExistingLoggedMilesInBaseline() {
        let shift = Shift(date: .now, grossIncome: 50_000)
        let trip = Trip(startDate: .now)
        trip.endDate = Date().addingTimeInterval(600)
        trip.distanceMiles = 1_000
        trip.tripType = .business
        let year = Calendar.current.component(.year, from: .now)

        let withExisting = WhatIfSimulator.simulate(shifts: [shift], trips: [trip], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 500)
        let withoutExisting = WhatIfSimulator.simulate(shifts: [shift], trips: [], expenses: [], driverProfile: nil, taxYear: year, extraMiles: 500)
        // Same extra miles, but the baseline (and therefore the tax savings)
        // should differ since one scenario already has 1,000 logged business miles.
        #expect(withExisting.baselineTotalTax != withoutExisting.baselineTotalTax)
    }
}
