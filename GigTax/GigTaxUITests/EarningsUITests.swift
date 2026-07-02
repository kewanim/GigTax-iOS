import XCTest

final class EarningsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLogShiftManuallyAppearsInEarningsList() throws {
        let app = XCUIApplication()
        app.launch()

        let earningsTab = app.tabBars.buttons["Earnings"]
        XCTAssertTrue(earningsTab.waitForExistence(timeout: 5))
        earningsTab.tap()

        XCTAssertTrue(app.navigationBars["Earnings"].waitForExistence(timeout: 5))
        app.navigationBars["Earnings"].buttons["addShiftMenu"].tap()

        let manualEntryButton = app.buttons["Log Shift Manually"]
        XCTAssertTrue(manualEntryButton.waitForExistence(timeout: 5))
        manualEntryButton.tap()

        XCTAssertTrue(app.navigationBars["Log Shift"].waitForExistence(timeout: 5))

        let grossField = app.textFields["grossIncomeField"]
        XCTAssertTrue(grossField.waitForExistence(timeout: 5))
        grossField.tap()
        grossField.typeText("125")

        app.navigationBars["Log Shift"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Manual"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["$125.00"].waitForExistence(timeout: 5))
    }
}
