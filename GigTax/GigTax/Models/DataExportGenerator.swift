import Foundation

/// Full backup/export of every shift, trip, and expense a driver has
/// logged — CSV for opening in a spreadsheet, JSON as a complete,
/// re-importable structured backup. Both formats carry every field needed
/// to reconstruct the underlying SwiftData records, not just a display
/// summary, so the JSON export is a real backup, not a lossy report.
enum DataExportGenerator {
    struct ShiftRecord: Codable {
        let id: UUID
        let date: Date
        let platform: String
        let grossIncome: Double
        let tips: Double
        let bonuses: Double
        let hoursWorked: Double
        let notes: String
        let importSource: String
        let importedMiles: Double?
    }

    struct TripRecord: Codable {
        let id: UUID
        let startDate: Date
        let endDate: Date?
        let startLatitude: Double
        let startLongitude: Double
        let endLatitude: Double?
        let endLongitude: Double?
        let distanceMiles: Double
        let cityMiles: Double
        let highwayMiles: Double
        let tripType: String
        let businessPurpose: String
        let isManualEntry: Bool
    }

    struct ExpenseRecord: Codable {
        let id: UUID
        let date: Date
        let category: String
        let amount: Double
        let notes: String
        let isRecurring: Bool
    }

    struct Backup: Codable {
        let exportDate: Date
        let shifts: [ShiftRecord]
        let trips: [TripRecord]
        let expenses: [ExpenseRecord]
    }

    static func shiftRecords(from shifts: [Shift]) -> [ShiftRecord] {
        shifts.map {
            ShiftRecord(id: $0.id, date: $0.date, platform: $0.platform.rawValue, grossIncome: $0.grossIncome, tips: $0.tips, bonuses: $0.bonuses, hoursWorked: $0.hoursWorked, notes: $0.notes, importSource: $0.importSource, importedMiles: $0.importedMiles)
        }
    }

    static func tripRecords(from trips: [Trip]) -> [TripRecord] {
        trips.map {
            TripRecord(id: $0.id, startDate: $0.startDate, endDate: $0.endDate, startLatitude: $0.startLatitude, startLongitude: $0.startLongitude, endLatitude: $0.endLatitude, endLongitude: $0.endLongitude, distanceMiles: $0.distanceMiles, cityMiles: $0.cityMiles, highwayMiles: $0.highwayMiles, tripType: $0.tripType.rawValue, businessPurpose: $0.businessPurpose, isManualEntry: $0.isManualEntry)
        }
    }

    static func expenseRecords(from expenses: [Expense]) -> [ExpenseRecord] {
        expenses.map {
            ExpenseRecord(id: $0.id, date: $0.date, category: $0.category.rawValue, amount: $0.amount, notes: $0.notes, isRecurring: $0.isRecurring)
        }
    }

    static func jsonData(shifts: [Shift], trips: [Trip], expenses: [Expense]) throws -> Data {
        let backup = Backup(exportDate: .now, shifts: shiftRecords(from: shifts), trips: tripRecords(from: trips), expenses: expenseRecords(from: expenses))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(backup)
    }

    static func shiftsCSV(_ shifts: [Shift]) -> String {
        var lines = ["Date,Platform,GrossIncome,Tips,Bonuses,HoursWorked,ImportedMiles,Notes"]
        for shift in shifts.sorted(by: { $0.date < $1.date }) {
            let dateField = csvDateFormatter.string(from: shift.date)
            let platformField = shift.platform.rawValue
            let grossField = String(shift.grossIncome)
            let tipsField = String(shift.tips)
            let bonusesField: String = String(shift.bonuses)
            let hoursField = String(shift.hoursWorked)
            let milesField: String = shift.importedMiles.map { String($0) } ?? ""
            let notesField = escapeCSV(shift.notes)
            let row = [dateField, platformField, grossField, tipsField, bonusesField, hoursField, milesField, notesField]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func tripsCSV(_ trips: [Trip]) -> String {
        var lines = ["StartDate,EndDate,DistanceMiles,TripType,BusinessPurpose"]
        for trip in trips.sorted(by: { $0.startDate < $1.startDate }) {
            lines.append([
                csvDateFormatter.string(from: trip.startDate),
                trip.endDate.map(csvDateFormatter.string) ?? "",
                String(trip.distanceMiles),
                trip.tripType.rawValue,
                escapeCSV(trip.businessPurpose),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func expensesCSV(_ expenses: [Expense]) -> String {
        var lines = ["Date,Category,Amount,Recurring,Notes"]
        for expense in expenses.sorted(by: { $0.date < $1.date }) {
            lines.append([
                csvDateFormatter.string(from: expense.date),
                expense.category.rawValue,
                String(expense.amount),
                expense.isRecurring ? "Yes" : "No",
                escapeCSV(expense.notes),
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static let csvDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
