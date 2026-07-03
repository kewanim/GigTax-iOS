import XCTest

final class VehicleUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddMaintenanceItemAppearsInSchedule() throws {
        let app = XCUIApplication()
        app.launch()

        let expensesTab = app.tabBars.buttons["Expenses"]
        XCTAssertTrue(expensesTab.waitForExistence(timeout: 5))
        expensesTab.tap()

        let vehicleDetailsLink = app.buttons["Vehicle Details"]
        XCTAssertTrue(vehicleDetailsLink.waitForExistence(timeout: 5))
        vehicleDetailsLink.tap()

        XCTAssertTrue(app.navigationBars["Vehicle Details"].waitForExistence(timeout: 5))

        let maintenanceLink = app.buttons["Maintenance Schedule"]
        XCTAssertTrue(maintenanceLink.waitForExistence(timeout: 5))
        maintenanceLink.tap()

        XCTAssertTrue(app.navigationBars["Maintenance Schedule"].waitForExistence(timeout: 5))
        app.navigationBars["Maintenance Schedule"].buttons["addMaintenanceItemButton"].tap()

        XCTAssertTrue(app.navigationBars["Add Maintenance Item"].waitForExistence(timeout: 5))
        // Oil Change is the default selection with sensible pre-filled defaults —
        // saving as-is is a valid golden path.
        app.navigationBars["Add Maintenance Item"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Oil Change"].waitForExistence(timeout: 5))
    }
}
