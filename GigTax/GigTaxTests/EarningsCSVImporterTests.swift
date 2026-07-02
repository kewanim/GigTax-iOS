import Testing
@testable import GigTax

struct EarningsCSVImporterTests {

    @Test func uberCSVAggregatesMultipleTripsPerDay() throws {
        let csv = """
        Trip Date,Fare,Tip,Promotion
        1/5/2026 8:03 AM,12.50,3.00,0.00
        1/5/2026 1:47 PM,9.25,1.50,2.00
        1/6/2026 9:15 AM,15.00,4.00,0.00
        """
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .uber, columnMap: EarningsCSVImporter.uber)
        #expect(shifts.count == 2)

        let jan5 = try #require(shifts.first)
        #expect(jan5.grossIncome == 21.75)
        #expect(jan5.tips == 4.50)
        #expect(jan5.bonuses == 2.00)
        #expect(jan5.importSource == "uber_csv")
        #expect(jan5.platform == .uber)

        let jan6 = try #require(shifts.last)
        #expect(jan6.grossIncome == 15.00)
    }

    @Test func lyftCSVHandlesQuotedFieldsWithCommas() throws {
        let csv = """
        Date,Ride Earnings,Tip,Bonus,Notes
        "2/1/2026","20.00","5.00","1.50","Airport run, long wait"
        """
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .lyft, columnMap: EarningsCSVImporter.lyft)
        #expect(shifts.count == 1)
        #expect(shifts.first?.grossIncome == 20.00)
        #expect(shifts.first?.bonuses == 1.50)
    }

    @Test func doorDashCSVMissingBonusColumnDefaultsToZero() throws {
        let csv = """
        Date,Base Pay,Tip
        3/10/2026,7.50,4.00
        3/10/2026,6.00,2.00
        """
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .doorDash, columnMap: EarningsCSVImporter.doorDashUberEats)
        #expect(shifts.count == 1)
        #expect(shifts.first?.grossIncome == 13.50)
        #expect(shifts.first?.tips == 6.00)
        #expect(shifts.first?.bonuses == 0)
        #expect(shifts.first?.importedMiles == nil)
    }

    @Test func doorDashCSVSumsDeliveryMilesWhenPresent() throws {
        let csv = """
        Date,Base Pay,Tip,Miles
        3/10/2026,7.50,4.00,3.2
        3/10/2026,6.00,2.00,2.8
        """
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .doorDash, columnMap: EarningsCSVImporter.doorDashUberEats)
        #expect(shifts.count == 1)
        #expect(shifts.first?.importedMiles == 6.0)
    }

    @Test func rowsWithUnparsableDatesAreSkippedNotThrown() throws {
        let csv = """
        Date,Base Pay,Tip
        not a date,7.50,4.00
        3/11/2026,6.00,2.00
        """
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .doorDash, columnMap: EarningsCSVImporter.doorDashUberEats)
        #expect(shifts.count == 1)
        #expect(shifts.first?.grossIncome == 6.00)
    }

    @Test func fileWithOnlyAHeaderThrowsEmptyFile() {
        let csv = "Trip Date,Fare,Tip,Promotion"
        #expect(throws: EarningsCSVError.emptyFile) {
            try EarningsCSVImporter.parse(csv: csv, platform: .uber, columnMap: EarningsCSVImporter.uber)
        }
    }

    @Test func fileMissingADateColumnThrowsMissingDateColumn() {
        let csv = """
        Fare,Tip,Promotion
        12.50,3.00,0.00
        """
        #expect(throws: EarningsCSVError.missingDateColumn) {
            try EarningsCSVImporter.parse(csv: csv, platform: .uber, columnMap: EarningsCSVImporter.uber)
        }
    }

    @Test func leadingBOMDoesNotBreakHeaderMatching() throws {
        let csv = "\u{FEFF}Date,Base Pay,Tip\n3/12/2026,10.00,2.00"
        let shifts = try EarningsCSVImporter.parse(csv: csv, platform: .doorDash, columnMap: EarningsCSVImporter.doorDashUberEats)
        #expect(shifts.count == 1)
        #expect(shifts.first?.grossIncome == 10.00)
    }
}
