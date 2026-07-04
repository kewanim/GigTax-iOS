import Foundation
import UIKit

/// Renders a driver's completed trips for a tax year into an IRS-audit-ready
/// PDF — the actual mileage log an auditor would want to see, not just a
/// list on screen. Uses UIGraphicsPDFRenderer directly (not a SwiftUI view
/// snapshot) so pagination is exact and predictable regardless of how many
/// trips a driver has logged.
enum MileageLogPDFGenerator {
    private static let pageWidth: CGFloat = 612   // 8.5in × 72pt/in
    private static let pageHeight: CGFloat = 792  // 11in × 72pt/in
    private static let margin: CGFloat = 36

    struct Totals {
        let tripCount: Int
        let totalMiles: Double
        let totalDeduction: Double
    }

    /// Pure, testable aggregate — separated from the PDF rendering so the
    /// numbers that appear on the document can be verified without needing
    /// to parse PDF bytes.
    static func totals(trips: [Trip]) -> Totals {
        let businessTrips = trips.filter { $0.isComplete && $0.tripType == .business }
        let miles = businessTrips.reduce(0) { $0 + $1.distanceMiles }
        return Totals(tripCount: businessTrips.count, totalMiles: miles, totalDeduction: miles * 0.70)
    }

    static func generate(trips: [Trip], driverName: String, vehicleDescription: String?, taxYear: Int) -> Data {
        let sortedTrips = trips
            .filter { $0.isComplete && $0.tripType == .business }
            .sorted { $0.startDate < $1.startDate }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            var y = beginPageWithHeader(context: context, driverName: driverName, vehicleDescription: vehicleDescription, taxYear: taxYear)

            for trip in sortedTrips {
                if y > pageHeight - 80 {
                    y = beginPageWithHeader(context: context, driverName: driverName, vehicleDescription: vehicleDescription, taxYear: taxYear, isContinuation: true)
                }
                y = drawRow(for: trip, at: y)
            }

            drawTotalsFooter(totals: totals(trips: trips), at: y)
        }
    }

    private static func beginPageWithHeader(context: UIGraphicsPDFRendererContext, driverName: String, vehicleDescription: String?, taxYear: Int, isContinuation: Bool = false) -> CGFloat {
        context.beginPage()
        var y = margin

        if !isContinuation {
            drawText("Mileage Log — Tax Year \(taxYear)", at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 18))
            y += 26
            drawText("Driver: \(driverName)", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 11))
            y += 16
            if let vehicleDescription {
                drawText("Vehicle: \(vehicleDescription)", at: CGPoint(x: margin, y: y), font: .systemFont(ofSize: 11))
                y += 16
            }
            y += 10
        }

        y = drawColumnHeaders(at: y)
        return y
    }

    private static func drawColumnHeaders(at y: CGFloat) -> CGFloat {
        let headerFont = UIFont.boldSystemFont(ofSize: 10)
        drawText("Date", at: CGPoint(x: margin, y: y), font: headerFont)
        drawText("From", at: CGPoint(x: margin + 60, y: y), font: headerFont)
        drawText("To", at: CGPoint(x: margin + 200, y: y), font: headerFont)
        drawText("Purpose", at: CGPoint(x: margin + 340, y: y), font: headerFont)
        drawText("Miles", at: CGPoint(x: pageWidth - margin - 40, y: y), font: headerFont)
        return y + 16
    }

    private static func drawRow(for trip: Trip, at y: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 9)
        let dateString = DateFormatter.pdfDateFormatter.string(from: trip.startDate)
        let origin = trip.startAddress ?? String(format: "%.3f, %.3f", trip.startLatitude, trip.startLongitude)
        let destination = trip.endAddress ?? "—"
        let purpose = trip.businessPurpose.isEmpty ? "(no purpose logged)" : trip.businessPurpose

        drawText(dateString, at: CGPoint(x: margin, y: y), font: font, maxWidth: 55)
        drawText(origin, at: CGPoint(x: margin + 60, y: y), font: font, maxWidth: 135)
        drawText(destination, at: CGPoint(x: margin + 200, y: y), font: font, maxWidth: 135)
        drawText(purpose, at: CGPoint(x: margin + 340, y: y), font: font, maxWidth: 150)
        drawText(String(format: "%.1f", trip.distanceMiles), at: CGPoint(x: pageWidth - margin - 40, y: y), font: font)
        return y + 14
    }

    private static func drawTotalsFooter(totals: Totals, at y: CGFloat) {
        let y = y + 16
        drawText("Total business trips: \(totals.tripCount)", at: CGPoint(x: margin, y: y), font: .boldSystemFont(ofSize: 10))
        drawText("Total miles: \(String(format: "%.1f", totals.totalMiles))", at: CGPoint(x: margin, y: y + 14), font: .boldSystemFont(ofSize: 10))
        drawText("Standard mileage deduction (@ $0.70/mi): \(totals.totalDeduction.formatted(.currency(code: "USD")))", at: CGPoint(x: margin, y: y + 28), font: .boldSystemFont(ofSize: 10))
    }

    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, maxWidth: CGFloat? = nil) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = maxWidth.map { CGSize(width: $0, height: 20) } ?? CGSize(width: 400, height: 20)
        (text as NSString).draw(in: CGRect(origin: point, size: size), withAttributes: attributes)
    }
}

private extension DateFormatter {
    static let pdfDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter
    }()
}
