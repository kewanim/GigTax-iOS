import XCTest

final class ExpensesUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogExpenseAppearsInExpensesList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        let expensesTab = app.tabBars.buttons["Expenses"]
        XCTAssertTrue(expensesTab.waitForExistence(timeout: 5))
        expensesTab.tap()

        XCTAssertTrue(app.navigationBars["Expenses"].waitForExistence(timeout: 5))
        app.navigationBars["Expenses"].buttons["addExpenseButton"].tap()

        XCTAssertTrue(app.navigationBars["Log Expense"].waitForExistence(timeout: 5))

        let amountField = app.textFields["expenseAmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("42.50")

        app.navigationBars["Log Expense"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["$42.50"].waitForExistence(timeout: 5))
    }
}
