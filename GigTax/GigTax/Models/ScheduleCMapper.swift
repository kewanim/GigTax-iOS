import Foundation

/// Maps the app's own deduction math onto the actual IRS Schedule C (Form
/// 1040) lines a driver needs to fill in — not a re-derivation of the tax
/// math itself, just a relabeling of numbers TaxEngine/DeductionMethodCalculator
/// already produced, so nothing here can disagree with the rest of the app.
enum ScheduleCMapper {
    struct LineItem {
        let line: String
        let label: String
        let amount: Double
    }

    struct Summary {
        let lineItems: [LineItem]
        let grossReceipts: Double
        let totalExpenses: Double
        let netProfit: Double
    }

    static func summary(comparison: DeductionMethodCalculator.Comparison, method: DeductionMethod, grossIncome: Double) -> Summary {
        let vehicleDeduction: Double = {
            switch method {
            case .standard: return comparison.standardMileageDeduction - comparison.nonVehicleExpenses
            case .actual: return comparison.actualExpenseDeduction - comparison.nonVehicleExpenses
            }
        }()
        let otherExpenses = comparison.nonVehicleExpenses
        let totalExpenses = vehicleDeduction + otherExpenses
        let netProfit = max(grossIncome - totalExpenses, 0)

        let lineItems = [
            LineItem(line: "Line 1", label: "Gross receipts or sales", amount: grossIncome),
            LineItem(line: "Line 9", label: "Car and truck expenses", amount: vehicleDeduction),
            LineItem(line: "Line 27a", label: "Other expenses (phone, supplies, etc.)", amount: otherExpenses),
            LineItem(line: "Line 28", label: "Total expenses", amount: totalExpenses),
            LineItem(line: "Line 29", label: "Tentative profit", amount: grossIncome - totalExpenses),
            LineItem(line: "Line 31", label: "Net profit (also goes on Schedule SE)", amount: netProfit),
        ]

        return Summary(lineItems: lineItems, grossReceipts: grossIncome, totalExpenses: totalExpenses, netProfit: netProfit)
    }
}
