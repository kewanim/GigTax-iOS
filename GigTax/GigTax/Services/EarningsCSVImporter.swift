import Foundation

/// Column-name aliases for one platform's earnings CSV export. Platforms
/// change their export format over time and by region, so each field is
/// matched against a list of known header variants rather than one exact name.
struct EarningsCSVColumnMap {
    let date: [String]
    let grossIncome: [String]
    let tips: [String]
    let bonuses: [String]
    let distanceMiles: [String]

    init(date: [String], grossIncome: [String], tips: [String], bonuses: [String], distanceMiles: [String] = []) {
        self.date = date
        self.grossIncome = grossIncome
        self.tips = tips
        self.bonuses = bonuses
        self.distanceMiles = distanceMiles
    }
}

enum EarningsCSVError: LocalizedError, Equatable {
    case emptyFile
    case missingDateColumn
    case noParsableRows

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "That file doesn't contain any rows."
        case .missingDateColumn:
            return "Couldn't find a date column in this file."
        case .noParsableRows:
            return "No rows had a date GigTax could recognize — check the file format."
        }
    }
}

enum EarningsCSVImporter {
    static let uber = EarningsCSVColumnMap(
        date: ["trip date", "date", "created", "request time", "requested at"],
        grossIncome: ["fare", "base fare", "trip earnings", "earnings", "net fare"],
        tips: ["tip", "tips"],
        bonuses: ["promotion", "promotions", "bonus", "surge", "quest bonus"]
    )

    static let lyft = EarningsCSVColumnMap(
        date: ["date", "ride date", "requested at", "ride requested"],
        grossIncome: ["ride earnings", "fare", "earnings", "your earnings"],
        tips: ["tip", "tips"],
        bonuses: ["bonus", "prime time", "streak bonus", "personal power zone", "ppz"]
    )

    static let doorDashUberEats = EarningsCSVColumnMap(
        date: ["date", "delivery date", "created at", "order date"],
        grossIncome: ["base pay", "pay", "order total", "base fare", "trip earnings"],
        tips: ["tip", "tips", "customer tip"],
        bonuses: ["peak pay", "promotion", "promotions", "bonus", "challenge bonus"],
        distanceMiles: ["miles", "distance", "distance (mi)", "delivery distance"]
    )

    /// Parses a CSV export into one Shift per calendar day, summing every
    /// trip/delivery row that falls on that day (platform CSVs are per-trip;
    /// GigTax tracks earnings at the shift/day level).
    static func parse(csv: String, platform: Platform, columnMap: EarningsCSVColumnMap) throws -> [Shift] {
        let text = CSVParsing.stripBOM(csv)
        let rows = CSVParsing.parseRows(text)
        guard let header = rows.first, rows.count > 1 else {
            throw EarningsCSVError.emptyFile
        }

        let normalizedHeader = header.map(CSVParsing.normalizeHeader)
        func columnIndex(for aliases: [String]) -> Int? {
            let normalizedAliases = Set(aliases.map(CSVParsing.normalizeHeader))
            return normalizedHeader.firstIndex { normalizedAliases.contains($0) }
        }

        guard let dateIdx = columnIndex(for: columnMap.date) else {
            throw EarningsCSVError.missingDateColumn
        }
        let fareIdx = columnIndex(for: columnMap.grossIncome)
        let tipIdx = columnIndex(for: columnMap.tips)
        let bonusIdx = columnIndex(for: columnMap.bonuses)
        let milesIdx = columnIndex(for: columnMap.distanceMiles)

        let calendar = Calendar.current
        var totals: [DateComponents: (gross: Double, tips: Double, bonuses: Double, miles: Double)] = [:]

        for row in rows.dropFirst() where row.count > dateIdx {
            guard let date = CSVParsing.parseDate(row[dateIdx]) else { continue }
            let day = calendar.dateComponents([.year, .month, .day], from: date)
            var entry = totals[day] ?? (0, 0, 0, 0)
            if let fareIdx, row.count > fareIdx { entry.gross += CSVParsing.parseAmount(row[fareIdx]) }
            if let tipIdx, row.count > tipIdx { entry.tips += CSVParsing.parseAmount(row[tipIdx]) }
            if let bonusIdx, row.count > bonusIdx { entry.bonuses += CSVParsing.parseAmount(row[bonusIdx]) }
            if let milesIdx, row.count > milesIdx { entry.miles += CSVParsing.parseAmount(row[milesIdx]) }
            totals[day] = entry
        }

        guard !totals.isEmpty else { throw EarningsCSVError.noParsableRows }

        let sourceTag = "\(platform.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))_csv"

        return totals.compactMap { day, sums in
            guard let date = calendar.date(from: day) else { return nil }
            return Shift(
                date: date,
                platform: platform,
                grossIncome: sums.gross,
                tips: sums.tips,
                bonuses: sums.bonuses,
                importSource: sourceTag,
                importedMiles: sums.miles > 0 ? sums.miles : nil
            )
        }.sorted { $0.date < $1.date }
    }
}
