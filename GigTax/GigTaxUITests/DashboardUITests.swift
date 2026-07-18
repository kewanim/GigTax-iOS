import XCTest

final class DashboardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardShowsEmptyStateThenPopulatesAfterLoggingAShift() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestReset"]
        app.launch()

        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: 5))
        dashboardTab.tap()

        XCTAssertTrue(app.staticTexts["No earnings yet"].waitForExistence(timeout: 5))

        let earningsTab = app.tabBars.buttons["Earnings"]
        earningsTab.tap()
        app.navigationBars["Earnings"].buttons["addShiftMenu"].tap()
        app.buttons["Log Shift Manually"].tap()

        let grossField = app.textFields["grossIncomeField"]
        XCTAssertTrue(grossField.waitForExistence(timeout: 5))
        grossField.tap()
        grossField.typeText("500")
        app.navigationBars["Log Shift"].buttons["Save"].tap()

        dashboardTab.tap()

        XCTAssertTrue(app.staticTexts["YTD Gross"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["$500.00"].waitForExistence(timeout: 5))
    }
}
