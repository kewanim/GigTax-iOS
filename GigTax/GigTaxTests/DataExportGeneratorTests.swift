import Testing
import Foundation
@testable import GigTax

struct DataExportGeneratorTests {

    @Test func jsonRoundTripsAllThreeRecordCounts() throws {
        let shift = Shift(date: .now, grossIncome: 100)
        let trip = Trip(startDate: .now)
        let expense = Expense(date: .now, category: .fuel, amount: 25)

        let data = try DataExportGenerator.jsonData(shifts: [shift], trips: [trip], expenses: [expense])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DataExportGenerator.Backup.self, from: data)

        #expect(backup.shifts.count == 1)
        #expect(backup.trips.count == 1)
        #expect(backup.expenses.count == 1)
        #expect(backup.shifts[0].grossIncome == 100)
    }

    @Test func jsonPreservesIDsForReimportMatching() throws {
        let shift = Shift(date: .now, grossIncome: 50)
        let data = try DataExportGenerator.jsonData(shifts: [shift], trips: [], expenses: [])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(DataExportGenerator.Backup.self, from: data)
        #expect(backup.shifts[0].id == shift.id)
    }

    @Test func shiftsCSVHasHeaderPlusOneRowPerShift() {
        let shift1 = Shift(date: .now, platform: .uber, grossIncome: 100, tips: 10, bonuses: 5)
        let shift2 = Shift(date: .now, platform: .lyft, grossIncome: 200, tips: 20, bonuses: 0)
        let csv = DataExportGenerator.shiftsCSV([shift1, shift2])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 3) // header + 2 rows
        #expect(lines[0].contains("GrossIncome"))
    }

    @Test func csvEscapesCommasAndQuotesInNotes() {
        let shift = Shift(date: .now, grossIncome: 100, notes: "Ran into traffic, lost time \"badly\"")
        let csv = DataExportGenerator.shiftsCSV([shift])
        // The escaped field should be quoted and internal quotes doubled.
        #expect(csv.contains("\"Ran into traffic, lost time \"\"badly\"\"\""))
    }

    @Test func emptyInputsProduceHeaderOnlyCSV() {
        let csv = DataExportGenerator.expensesCSV([])
        let lines = csv.split(separator: "\n")
        #expect(lines.count == 1)
    }

    @Test func tripsCSVIncludesDistanceAndPurpose() {
        let trip = Trip(startDate: .now)
        trip.distanceMiles = 42.5
        trip.businessPurpose = "Uber driving"
        let csv = DataExportGenerator.tripsCSV([trip])
        #expect(csv.contains("42.5"))
        #expect(csv.contains("Uber driving"))
    }
}
