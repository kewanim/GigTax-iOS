import Foundation
import Vision
import UIKit

/// Best-effort extraction from a screenshot of a platform's weekly (or daily)
/// earnings summary — the practical reality is most drivers can screenshot
/// their Uber/Lyft app but can't export a CSV. OCR + heuristic parsing is
/// inherently approximate, so every field here is a starting guess the driver
/// reviews and can correct before saving, never written directly to a Shift.
struct ParsedWeeklyEarnings {
    var platform: Platform?
    var startDate: Date?
    var endDate: Date?
    var grossIncome: Double?
    var tips: Double?
    var hoursWorked: Double?
    var miles: Double?
}

enum EarningsScreenshotParser {
    enum ParserError: LocalizedError {
        case noTextFound

        var errorDescription: String? {
            "Couldn't read any text from that screenshot. Try a clearer or less-cropped image, or enter the shift manually."
        }
    }

    /// Runs Vision text recognition and returns recognized lines, top-to-bottom.
    static func recognizeText(in image: UIImage) throws -> [String] {
        guard let cgImage = image.cgImage else { throw ParserError.noTextFound }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw ParserError.noTextFound
        }

        // Vision's bounding boxes use a bottom-left origin — sort by
        // descending y to approximate top-to-bottom reading order, since
        // observations aren't guaranteed to already be in that order.
        let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
        return sorted.compactMap { $0.topCandidates(1).first?.string }
    }

    static func parse(lines: [String]) -> ParsedWeeklyEarnings {
        var result = ParsedWeeklyEarnings()
        let lowerJoined = lines.joined(separator: "\n").lowercased()

        if lowerJoined.contains("lyft") {
            result.platform = .lyft
        } else if lowerJoined.contains("uber") {
            result.platform = .uber
        }

        if let (start, end) = parseDateRange(lines: lines) {
            result.startDate = start
            result.endDate = end
        }

        // A standalone "Tips" line (Lyft's phrasing) is a real data row.
        // "Excluding tips" / "Excludes tips of $X" are descriptive sentences
        // that merely mention the word — try an exact-line match first so
        // those don't get mistaken for the tips row itself.
        result.tips = firstAmount(matchingLineExactly: "tips", in: lines)
            ?? firstAmount(afterKeyword: "tips", in: lines)
            ?? firstAmount(afterKeyword: "tip", in: lines)

        // Prefer "Your earnings" (Uber's phrasing) — it already excludes tips.
        // Fall back to "Total earnings" (Lyft's phrasing), which includes
        // tips, so subtract them back out to avoid Shift double-counting
        // gross + tips.
        if let yourEarnings = firstAmount(afterKeyword: "your earnings", in: lines) {
            result.grossIncome = yourEarnings
        } else if let total = firstAmount(afterKeyword: "total earnings", in: lines) {
            result.grossIncome = max(total - (result.tips ?? 0), 0)
        }

        result.miles = firstMiles(in: lines)
        result.hoursWorked = firstHours(in: lines)

        return result
    }

    private static func firstAmount(matchingLineExactly keyword: String, in lines: [String]) -> Double? {
        guard let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == keyword }) else {
            return nil
        }
        let windowStart = max(index - 2, 0)
        let windowEnd = min(index + 3, lines.count)
        let candidates = (windowStart..<windowEnd)
            .map { (distance: abs($0 - index), text: lines[$0]) }
            .sorted { $0.distance < $1.distance }
        for candidate in candidates {
            if let amount = extractDollarAmount(from: candidate.text) {
                return amount
            }
        }
        return nil
    }

    private static func firstAmount(afterKeyword keyword: String, in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() {
            guard line.lowercased().contains(keyword) else { continue }
            // The label and its dollar value are frequently split into
            // separate OCR text observations — and, since these screenshots
            // right-align the amount next to a left-aligned (often wrapped)
            // label, Vision's top-to-bottom reading order just as often puts
            // the amount line *before* the label as after it. Search
            // outward from the keyword line in both directions, closest
            // first, rather than assuming only "after."
            let windowStart = max(index - 2, 0)
            let windowEnd = min(index + 3, lines.count)
            let candidates = (windowStart..<windowEnd)
                .map { (distance: abs($0 - index), text: lines[$0]) }
                .sorted { $0.distance < $1.distance }
            for candidate in candidates {
                if let amount = extractDollarAmount(from: candidate.text) {
                    return amount
                }
            }
        }
        return nil
    }

    private static func extractDollarAmount(from text: String) -> Double? {
        guard let match = text.range(of: #"-?\$?\d[\d,]*\.\d{2}"#, options: .regularExpression) else { return nil }
        let cleaned = text[match]
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleaned)
    }

    private static func firstMiles(in lines: [String]) -> Double? {
        for line in lines {
            guard let match = line.range(of: #"\d+(\.\d+)?\s*mi\b"#, options: [.regularExpression, .caseInsensitive]) else { continue }
            let numberPart = line[match].replacingOccurrences(of: "mi", with: "", options: [.caseInsensitive])
            if let value = Double(numberPart.trimmingCharacters(in: .whitespaces)) {
                return value
            }
        }
        return nil
    }

    private static func firstHours(in lines: [String]) -> Double? {
        for line in lines {
            guard line.range(of: #"\d+\s*hr\b"#, options: [.regularExpression, .caseInsensitive]) != nil else { continue }
            let hours = firstNumber(before: "hr", in: line) ?? 0
            let minutes = firstNumber(before: "min", in: line) ?? 0
            if hours > 0 || minutes > 0 {
                return hours + minutes / 60
            }
        }
        return nil
    }

    private static func firstNumber(before suffix: String, in text: String) -> Double? {
        let pattern = #"\d+(?=\s*"# + NSRegularExpression.escapedPattern(for: suffix) + ")"
        guard let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return Double(text[match])
    }

    private static let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private static func parseDateRange(lines: [String]) -> (start: Date, end: Date)? {
        let monthPattern = monthNames.joined(separator: "|")
        let pattern = "(\(monthPattern)) (\\d{1,2})\\s*[-–]\\s*(?:(\(monthPattern)) )?(\\d{1,2})"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        for line in lines {
            let nsrange = NSRange(line.startIndex..., in: line)
            guard let result = regex.firstMatch(in: line, range: nsrange) else { continue }

            func group(_ index: Int) -> String? {
                guard let range = Range(result.range(at: index), in: line) else { return nil }
                return String(line[range])
            }

            guard let startMonthStr = group(1), let startDayStr = group(2), let startDay = Int(startDayStr) else { continue }
            let endMonthStr = group(3) ?? startMonthStr
            guard let endDayStr = group(4), let endDay = Int(endDayStr) else { continue }
            guard let startMonthIdx = monthNames.firstIndex(where: { $0.caseInsensitiveCompare(startMonthStr) == .orderedSame }),
                  let endMonthIdx = monthNames.firstIndex(where: { $0.caseInsensitiveCompare(endMonthStr) == .orderedSame }) else { continue }

            let year = Calendar.current.component(.year, from: .now)
            let startComponents = DateComponents(year: year, month: startMonthIdx + 1, day: startDay)
            let endComponents = DateComponents(year: year, month: endMonthIdx + 1, day: endDay)
            guard let startDate = Calendar.current.date(from: startComponents),
                  let endDate = Calendar.current.date(from: endComponents) else { continue }
            return (startDate, endDate)
        }
        return nil
    }
}
