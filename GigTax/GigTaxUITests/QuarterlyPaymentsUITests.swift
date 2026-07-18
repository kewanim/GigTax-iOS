import XCTest

final class QuarterlyPaymentsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogPaymentAppearsInQuarterlyPaymentsList() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
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

        // "Paid So Far" row is grouped into one VoiceOver element (accessibilityElement(children: .combine)),
        // so the amount reads as part of the combined label rather than as its own static text.
        XCTAssertTrue(app.staticTexts["Paid So Far, $1,500.00"].waitForExistence(timeout: 5))
    }
}
