//
//  DrawerFeelUITests.swift
//  LensirUITests
//
//  The four drags that show how the drawer feels, run with real touches:
//  a fast flick, a slow drag past half, a pull past the top that rubber
//  bands back, and catching it while it closes. scripts/record-drawer.sh
//  records each one in the Simulator.
//

import XCTest

@MainActor
final class DrawerFeelUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ scene: String, _ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-LensirDemo", scene, "-LensirNoSplash"] + extra
        app.launch()
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        // Let the drawer finish rising before touching it.
        Thread.sleep(forTimeInterval: 0.8)
    }

    private var grabber: XCUIElement { app.descendants(matching: .any)["drawer-grabber"] }

    private func point(_ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: y))
    }

    private func expectGone() {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: grabber)
        waitForExpectations(timeout: 3)
    }

    private func expectLabel(_ label: String) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: grabber)
        waitForExpectations(timeout: 3)
    }

    /// 60 pt, fast: closes, though it's nowhere near half way.
    func testFastFlickDismisses() {
        launch("safe")
        point(0.78).press(forDuration: 0.05, thenDragTo: point(0.85), withVelocity: 2500, thenHoldForDuration: 0)
        expectGone()
    }

    /// Slowly past half the drawer's height, held still, then let go:
    /// closes on distance alone.
    func testSlowDragPastHalfDismisses() {
        launch("safe")
        let top = grabber.frame.midY / app.frame.height
        let travel = 1 - top
        point(top).press(forDuration: 0.1, thenDragTo: point(top + travel * 0.6), withVelocity: 300, thenHoldForDuration: 0.4)
        expectGone()
    }

    /// Slowly, but less than a third of the way: comes back to compact.
    func testSlowShortDragSnapsBack() {
        launch("safe")
        let before = grabber.frame.minY
        let top = grabber.frame.midY / app.frame.height
        point(top).press(forDuration: 0.1, thenDragTo: point(top + (1 - top) * 0.25), withVelocity: 300, thenHoldForDuration: 0.4)
        expectLabel("Expand details")
        XCTAssertEqual(grabber.frame.minY, before, accuracy: 1)
    }

    /// Expanded, pulled up past the top: it gives a little, then comes back
    /// to exactly where it was.
    func testPullPastTopRubberBandsBack() {
        launch("safe-expanded")
        expectLabel("Collapse details")
        let before = grabber.frame.minY
        let start = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -300)),
                    withVelocity: 600, thenHoldForDuration: 0.4)
        expectLabel("Collapse details")
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(grabber.frame.minY, before, accuracy: 1)
    }

    /// Closing (tapped away above it), caught on the way down and pushed
    /// back up: it stays open. The springs run 4× slower here, since a UI
    /// test can't touch down again within a 0.3 s close.
    func testCatchWhileClosing() {
        launch("safe", ["-LensirDrawerSlow"])
        point(0.15).tap()
        point(0.9).press(forDuration: 0.05, thenDragTo: point(0.6), withVelocity: 800, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertTrue(grabber.exists, "The drawer closed under the finger")
    }
}
