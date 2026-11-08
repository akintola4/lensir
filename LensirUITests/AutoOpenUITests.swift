//
//  AutoOpenUITests.swift
//  LensirUITests
//
//  "Open results right away", with real touches. `-LensirDemo live` reports
//  the demo code ten times a second, the way a camera does, and
//  `-LensirAutoOpen` turns the setting on for the run without saving it.
//  XCTest because Swift Testing can't drive the UI.
//

import XCTest

@MainActor
final class AutoOpenUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments + ["-LensirNoSplash"]
        app.launch()
    }

    private var grabber: XCUIElement { app.descendants(matching: .any)["drawer-grabber"] }
    private var pill: XCUIElement { app.descendants(matching: .any)["found-pill"] }

    private func point(_ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
    }

    /// On: the drawer comes up at its compact height with no tap on the
    /// pill. Flicked away while the code is still in view, it stays away,
    /// and the pill is back to tap.
    func testCodeOpensTheDrawerWithoutTappingThePill() {
        launch(["-LensirDemo", "live", "-LensirAutoOpen"])
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        XCTAssertEqual(grabber.label, "Expand details", "It should open compact")

        // A fast flick down from the content, a real touch.
        point(0.8).press(forDuration: 0.05, thenDragTo: point(0.9), withVelocity: 2500, thenHoldForDuration: 0)
        XCTAssertTrue(grabber.waitForNonExistence(timeout: 3))

        // The camera sees the same code again: pill, no drawer.
        XCTAssertTrue(pill.waitForExistence(timeout: 3))
        XCTAssertFalse(grabber.waitForExistence(timeout: 2.5), "The closed code popped its drawer again")

        // The pill still works.
        pill.tap()
        XCTAssertTrue(grabber.waitForExistence(timeout: 3))
    }

    /// Off, as it ships: the pill waits for a tap.
    func testOffWaitsForThePill() {
        launch(["-LensirDemo", "live"])
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        XCTAssertFalse(grabber.waitForExistence(timeout: 1.5))
        pill.tap()
        XCTAssertTrue(grabber.waitForExistence(timeout: 3))
    }

    /// The switch is in Settings, under Haptics, and starts off.
    func testSettingIsThereAndOff() {
        launch(["-LensirDemo", "looking", "-LensirOpenHistory"])
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        let toggle = app.switches["Open results right away"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertTrue(app.staticTexts["Show the details as soon as a code is found, without tapping it."].exists)
    }
}
