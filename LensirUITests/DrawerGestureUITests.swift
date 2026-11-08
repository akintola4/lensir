//
//  DrawerGestureUITests.swift
//  LensirUITests
//
//  Real touches on the result drawer, because who gets a drag (the drawer,
//  the scroll view or a button) only shows up with real gestures. XCTest is
//  here only because Swift Testing can't drive the UI.
//
//  Each test opens a demo scene so no camera is needed. Positions are
//  fractions of the screen, so they hold on any iPhone.
//

import XCTest

@MainActor
final class DrawerGestureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ scene: String) {
        app = XCUIApplication()
        app.launchArguments = ["-LensirDemo", scene]
        app.launch()
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
    }

    private var grabber: XCUIElement { app.descendants(matching: .any)["drawer-grabber"] }

    private func point(_ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
    }

    /// A slow drag that stops before letting go, so it lands by position.
    private func drag(from: CGFloat, to: CGFloat) {
        point(from).press(forDuration: 0.1, thenDragTo: point(to), withVelocity: 500, thenHoldForDuration: 0.3)
    }

    private func expectLabel(_ label: String) {
        let matches = NSPredicate(format: "label == %@", label)
        expectation(for: matches, evaluatedWith: grabber)
        waitForExpectations(timeout: 3)
    }

    /// Expanded, content at the top: dragging down from the middle of the
    /// Details collapses the drawer. No reaching for the grabber.
    func testDragDownFromContentCollapses() {
        launch("safe-expanded")
        expectLabel("Collapse details")
        drag(from: 0.55, to: 0.95)
        expectLabel("Expand details")
    }

    /// Expanded and scrolled down: the same drag scrolls back to the top
    /// first, then carries on and collapses the drawer, in one movement.
    func testDragDownScrollsBackThenCollapses() {
        launch("safe-expanded")
        let checks = app.staticTexts["Checks"]
        XCTAssertTrue(checks.waitForExistence(timeout: 3))
        let before = checks.frame.minY
        drag(from: 0.85, to: 0.45)
        XCTAssertLessThan(checks.frame.minY, before - 40, "Details should have scrolled")
        expectLabel("Collapse details")
        drag(from: 0.4, to: 0.99)
        expectLabel("Expand details")
    }

    /// The header is always a handle, even with Details scrolled away.
    func testHeaderDragCollapsesWhileScrolled() {
        launch("safe-expanded")
        drag(from: 0.85, to: 0.45)
        drag(from: 0.13, to: 0.6)
        expectLabel("Expand details")
    }

    /// Compact: dragging up from the content, not the grabber, expands it.
    func testDragUpFromContentExpands() {
        launch("safe")
        expectLabel("Expand details")
        drag(from: 0.78, to: 0.4)
        expectLabel("Collapse details")
    }

    /// A drag that starts on a button moves the drawer and doesn't press
    /// the button, even though the drawer carries the button along under
    /// the finger to the release point.
    func testDragFromAButtonDoesNotPressIt() {
        launch("safe")
        let open = app.buttons["Open in Safari"]
        XCTAssertTrue(open.waitForExistence(timeout: 3))
        let start = open.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)), withVelocity: 500, thenHoldForDuration: 0.3)
        expectLabel("Collapse details")
        XCTAssertEqual(app.state, .runningForeground, "Safari opened: the drag pressed the button")
    }

    /// Compact: a short, fast flick down from the content closes it.
    func testFlickDownFromContentDismisses() {
        launch("safe")
        point(0.8).press(forDuration: 0.05, thenDragTo: point(0.9), withVelocity: 2500, thenHoldForDuration: 0)
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: grabber)
        waitForExpectations(timeout: 3)
    }

    /// Taps on buttons still land: the drag only starts after 8 pt.
    func testTapOnButtonStillWorks() {
        launch("safe")
        app.buttons["Copy link"].tap()
        XCTAssertTrue(app.buttons["Copied"].waitForExistence(timeout: 2))
        expectLabel("Expand details")
    }

    /// Tapping the grabber still toggles.
    func testGrabberTapToggles() {
        launch("safe")
        grabber.tap()
        expectLabel("Collapse details")
        grabber.tap()
        expectLabel("Expand details")
    }
}
