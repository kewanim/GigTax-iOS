import XCTest

final class QuarterlyPaymentsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogPaymentAppearsInQuarterlyPaymentsList() throws {
        let app = XCUIApplication()
        app.launch()

        let earningsTab = app.tabBars.buttons["Earnings"]
        XCTAssertTrue(earningsTab.waitForExistence(timeout: 5))
        earningsTab.tap()

        let quarterlyLink = app.buttons["Quarterly Taxes"]
        XCTAssertTrue(quarterlyLink.waitForExistence(timeout: 5))
        quarterlyLink.tap()

        XCTAssertTrue(app.navigationBars["Quarterly Taxes"].waitForExistence(timeout: 5))
        app.navigationBars["Quarterly Taxes"].buttons["addQuarterlyPaymentButton"].tap()

        XCTAssertTrue(app.navigationBars["Log Payment"].waitForExistence(timeout: 5))

        let amountField = app.textFields["quarterlyPaymentAmountField"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 5))
        amountField.tap()
        amountField.typeText("1500")

        app.navigationBars["Log Payment"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["$1,500.00"].waitForExistence(timeout: 5))
    }
}
