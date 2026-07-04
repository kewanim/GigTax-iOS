import XCTest

final class AuditShieldUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMileageLogAndAuditShieldAreReachableFromTrips() throws {
        let app = XCUIApplication()
        app.launch()

        let tripsTab = app.tabBars.buttons["Trips"]
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 5))
        tripsTab.tap()

        let mileageLogLink = app.buttons["Mileage Log"]
        XCTAssertTrue(mileageLogLink.waitForExistence(timeout: 5))
        mileageLogLink.tap()
        XCTAssertTrue(app.navigationBars["Mileage Log"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap() // back

        let auditShieldLink = app.buttons["Audit Shield"]
        XCTAssertTrue(auditShieldLink.waitForExistence(timeout: 5))
        auditShieldLink.tap()
        XCTAssertTrue(app.navigationBars["Audit Shield"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["What triggers an audit?"].waitForExistence(timeout: 5))
    }
}
