import Testing
import Foundation
@testable import GigTax

struct VehicleDepreciationCalculatorTests {

    @Test func belowFiftyPercentBusinessUseProducesNoDeduction() {
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 30_000, businessUsePercent: 50, useBonusDepreciation: true)
        #expect(result.schedule.isEmpty)
        #expect(result.depreciableBasis == 0)
    }

    @Test func exactlyFiftyPercentIsNotEligible() {
        // IRS requires MORE than 50%, not "at least" 50%.
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 30_000, businessUsePercent: 50.0, useBonusDepreciation: true)
        #expect(result.schedule.isEmpty)
    }

    @Test func fullBusinessUseYear1CapWithBonusIsTwentyThousandTwoHundred() {
        // Expensive enough vehicle that Year 1 hits the cap, not the full basis.
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 50_000, businessUsePercent: 100, useBonusDepreciation: true)
        #expect(abs(result.deduction(forYear: 1) - 20_200) < 0.01)
    }

    @Test func fullBusinessUseYear1CapWithoutBonusIsTwelveThousandTwoHundred() {
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 50_000, businessUsePercent: 100, useBonusDepreciation: false)
        #expect(abs(result.deduction(forYear: 1) - 12_200) < 0.01)
    }

    @Test func capsAreProratedByBusinessUsePercent() {
        // 70% business use → 70% of the $20,200 Year 1 cap.
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 50_000, businessUsePercent: 70, useBonusDepreciation: true)
        let expectedYear1 = 20_200 * 0.70
        #expect(abs(result.deduction(forYear: 1) - expectedYear1) < 0.01)
    }

    @Test func cheapVehicleFullyDepreciatesInYearOneWithoutHittingTheCap() {
        // $10,000 vehicle, 100% business use, bonus depreciation: basis
        // ($10,000) is under the $20,200 cap, so it should fully deduct in
        // year 1 with nothing left for later years.
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 10_000, businessUsePercent: 100, useBonusDepreciation: true)
        #expect(abs(result.deduction(forYear: 1) - 10_000) < 0.01)
        #expect(result.schedule.count == 1)
    }

    @Test func expensiveVehicleSpreadsAcrossMultipleYearsUsingSucceedingYearCaps() {
        // $60,000 vehicle, 100% business use, bonus depreciation.
        // Year 1: $20,200. Year 2: $19,600. Year 3: $11,800.
        // Remaining basis after 3 years: 60,000 - 20,200 - 19,600 - 11,800 = 8,400.
        // Year 4 cap is $7,060, so year 4 takes $7,060, leaving $1,340 for year 5.
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 60_000, businessUsePercent: 100, useBonusDepreciation: true)
        #expect(abs(result.deduction(forYear: 1) - 20_200) < 0.01)
        #expect(abs(result.deduction(forYear: 2) - 19_600) < 0.01)
        #expect(abs(result.deduction(forYear: 3) - 11_800) < 0.01)
        #expect(abs(result.deduction(forYear: 4) - 7_060) < 0.01)
        #expect(abs(result.deduction(forYear: 5) - 1_340) < 0.01)
    }

    @Test func totalDeductedNeverExceedsDepreciableBasis() {
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 45_000, businessUsePercent: 85, useBonusDepreciation: true, numberOfYears: 6)
        #expect(result.totalDeductedSoFar <= result.depreciableBasis + 0.01)
    }

    @Test func zeroVehicleCostProducesNoDeduction() {
        let result = VehicleDepreciationCalculator.calculate(vehicleCost: 0, businessUsePercent: 100, useBonusDepreciation: true)
        #expect(result.schedule.isEmpty)
    }

    @Test func scheduleYearComputesCorrectlyFromPlacedInServiceYear() {
        #expect(VehicleDepreciationCalculator.scheduleYear(placedInServiceYear: 2025, taxYear: 2025) == 1)
        #expect(VehicleDepreciationCalculator.scheduleYear(placedInServiceYear: 2025, taxYear: 2027) == 3)
        #expect(VehicleDepreciationCalculator.scheduleYear(placedInServiceYear: 2023, taxYear: 2025) == 3)
    }
}
