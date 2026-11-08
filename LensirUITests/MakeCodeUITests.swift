//
//  MakeCodeUITests.swift
//  LensirUITests
//
//  Making a code with real taps and the real keyboard: open Make, type a
//  link, keep it, and find it in My codes. XCTest because Swift Testing
//  can't drive the UI.
//

import XCTest

@MainActor
final class MakeCodeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // A demo scene keeps everything in memory, so nothing real is kept.
        app.launchArguments = ["-LensirDemo", "looking", "-LensirNoSplash"]
        app.launch()
    }

    func testMakeALinkKeepItAndFindItInMyCodes() {
        let make = app.buttons["make-button"]
        XCTAssertTrue(make.waitForExistence(timeout: 5))
        make.tap()

        let linkChip = app.buttons["make-kind-link"]
        XCTAssertTrue(linkChip.waitForExistence(timeout: 3))
        linkChip.tap()
        let field = app.textFields["make-field-link"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("kolalogistics.test/track")

        // The code drew itself as we typed.
        let preview = app.descendants(matching: .any)["make-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 2))
        XCTAssertEqual(preview.label, "QR code for link to kolalogistics.test")
        XCTAssertTrue(app.staticTexts["Secure · nothing odd in the address"].waitForExistence(timeout: 3))

        let keep = app.buttons["make-keep"]
        XCTAssertTrue(keep.isHittable, "Keep should sit above the keyboard")
        keep.tap()
        let kept = NSPredicate(format: "label == %@", "Kept in My codes")
        expectation(for: kept, evaluatedWith: keep)
        waitForExpectations(timeout: 3)

        // Return puts the keyboard away; then tap above the drawer to close it.
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        XCTAssertTrue(preview.waitForNonExistence(timeout: 3))
        app.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "kolalogistics.test")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertTrue(row.label.contains("Link"))

        // Tap it: the code full screen, and back.
        row.tap()
        let code = app.descendants(matching: .any)["code-image"]
        XCTAssertTrue(code.waitForExistence(timeout: 3))
        XCTAssertEqual(code.label, "QR code for link to kolalogistics.test")
        app.buttons["code-close"].tap()
        XCTAssertTrue(code.waitForNonExistence(timeout: 3))
    }

    /// A risky link asks before it's kept.
    func testARiskyLinkAsksFirst() {
        let make = app.buttons["make-button"]
        XCTAssertTrue(make.waitForExistence(timeout: 5))
        make.tap()
        let linkChip = app.buttons["make-kind-link"]
        XCTAssertTrue(linkChip.waitForExistence(timeout: 3))
        linkChip.tap()
        let field = app.textFields["make-field-link"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("http://bit.ly/3kQ9xZp")
        app.buttons["make-keep"].tap()
        let alert = app.alerts["This link looks risky"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["make-keep"].label, "Keep in My codes")
    }
}
