//
//  ScanLinkUITests.swift
//  LensirUITests
//
//  lensir://scan, opened the way the Lock Screen widget opens it, while
//  something covers the camera: it has to close and leave the scanner.
//  XCTest because Swift Testing can't drive the UI.
//

import XCTest

@MainActor
final class ScanLinkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments + ["-LensirNoSplash"]
        app.launch()
    }

    /// Opens the link from outside, and answers the Simulator's "Open in
    /// Lensir?" if it asks (a phone doesn't, for a widget tap).
    private func openScanLink() {
        XCUIDevice.shared.system.open(URL(string: "lensir://scan")!)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let open = springboard.buttons["Open"]
        if open.waitForExistence(timeout: 3) { open.tap() }
    }

    private var hint: XCUIElement { app.staticTexts["Point at a QR code"] }

    func testScanLinkClosesHistory() {
        launch(["-LensirDemo", "looking", "-LensirOpenHistory"])
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        openScanLink()
        XCTAssertTrue(app.navigationBars["History"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(hint.waitForExistence(timeout: 3))
    }

    /// Opened by tapping the pill rather than a scene that opens the drawer
    /// itself, since those reopen it as soon as it closes.
    func testScanLinkClosesTheResultDrawer() {
        launch(["-LensirDemo", "found"])
        let pill = app.descendants(matching: .any)["found-pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        let grabber = app.descendants(matching: .any)["drawer-grabber"]
        XCTAssertTrue(grabber.waitForExistence(timeout: 5))
        openScanLink()
        XCTAssertTrue(grabber.waitForNonExistence(timeout: 5))
    }
}
