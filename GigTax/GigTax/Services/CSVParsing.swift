import Foundation

/// Minimal RFC 4180 CSV reader: handles quoted fields (with embedded commas,
/// newlines, and escaped "" quotes) and both CRLF and LF line endings.
enum CSVParsing {
    static func parseRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var row: [String] = []
        var inQuotes = false
        let chars = Array(text.unicodeScalars)
        var i = 0

        func endField() { row.append(field); field = "" }
        func endRow() { endField(); rows.append(row); row = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" {
                        field.unicodeScalars.append(c)
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.unicodeScalars.append(c)
                }
            } else if c == "\"" {
                inQuotes = true
            } else if c == "," {
                endField()
            } else if c == "\n" {
                endRow()
            } else if c == "\r" {
                // swallow; a following \n (if any) will end the row
            } else {
                field.unicodeScalars.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { endRow() }

        return rows.filter { !($0.count == 1 && $0[0].trimmingCharacters(in: .whitespaces).isEmpty) }
    }

    static func stripBOM(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }

    static func normalizeHeader(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func parseAmount(_ raw: String) -> Double {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        if cleaned.hasPrefix("("), cleaned.hasSuffix(")") {
            let inner = cleaned.dropFirst().dropLast()
            return -(Double(inner) ?? 0)
        }
        return Double(cleaned) ?? 0
    }

    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "M/d/yyyy h:mm:ss a", "M/d/yyyy h:mm a", "M/d/yyyy H:mm", "M/d/yyyy",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd",
            "MMM d, yyyy", "MMMM d, yyyy",
        ]
        return formats.map { format in
            let df = DateFormatter()
            df.dateFormat = format
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = .current
            return df
        }
    }()

    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}
