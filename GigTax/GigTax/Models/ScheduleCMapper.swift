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
        // Depreciation gets its own Schedule C line (13), separate from
        // Line 9's vehicle *operating* expenses — standard mileage bakes
        // depreciation into the per-mile rate, so it only appears as its
        // own line under the actual expense method.
        let depreciationAmount = method == .actual ? comparison.depreciationDeduction : 0
        let vehicleDeduction: Double = {
            switch method {
            case .standard: return comparison.standardMileageDeduction - comparison.nonVehicleExpenses
            case .actual: return comparison.actualExpenseDeduction - comparison.nonVehicleExpenses - comparison.depreciationDeduction
            }
        }()
        let otherExpenses = comparison.nonVehicleExpenses
        let totalExpenses = vehicleDeduction + depreciationAmount + otherExpenses
        let netProfit = max(grossIncome - totalExpenses, 0)

        var lineItems = [
            LineItem(line: "Line 1", label: "Gross receipts or sales", amount: grossIncome),
            LineItem(line: "Line 9", label: "Car and truck expenses", amount: vehicleDeduction),
        ]
        if depreciationAmount > 0 {
            lineItems.append(LineItem(line: "Line 13", label: "Depreciation and Section 179 expense deduction", amount: depreciationAmount))
        }
        lineItems.append(contentsOf: [
            LineItem(line: "Line 27a", label: "Other expenses (phone, supplies, etc.)", amount: otherExpenses),
            LineItem(line: "Line 28", label: "Total expenses", amount: totalExpenses),
            LineItem(line: "Line 29", label: "Tentative profit", amount: grossIncome - totalExpenses),
            LineItem(line: "Line 31", label: "Net profit (also goes on Schedule SE)", amount: netProfit),
        ])

        return Summary(lineItems: lineItems, grossReceipts: grossIncome, totalExpenses: totalExpenses, netProfit: netProfit)
    }
}
