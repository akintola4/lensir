//
//  ReviewFixesTests.swift
//  LensirTests
//
//  Where VoiceOver lands when the drawer closes, the drawer closing faster
//  than it opens, History's row symbols, the Increase Contrast grey, and the
//  Reduce Motion credit clearing before the scanner's buttons come in.
//

import CoreGraphics
import Testing
import SwiftUI
import UIKit
@testable import Lensir

@Suite("Scanner focus")
struct ScannerFocusTests {
    @Test func promptShowsWhileTheCameraWaits() {
        #expect(ScannerFocusLogic.hintText(notice: nil, cameraIsLive: true, codeInView: false) == "Point at a QR code")
        #expect(ScannerFocusLogic.hintText(notice: nil, cameraIsLive: true, codeInView: true) == nil)
        #expect(ScannerFocusLogic.hintText(notice: nil, cameraIsLive: false, codeInView: false) == nil)
        #expect(ScannerFocusLogic.hintText(notice: "No code in that photo", cameraIsLive: false, codeInView: false) == "No code in that photo")
    }

    @Test func closingTheDrawerFocusesThePromptOrScanAPhoto() {
        #expect(ScannerFocusLogic.afterDrawerCloses(hint: "Point at a QR code") == .hint)
        // No camera, so no prompt: Scan a photo is the way on.
        #expect(ScannerFocusLogic.afterDrawerCloses(hint: nil) == .photoButton)
    }
}

@Suite("Drawer timing")
struct DrawerTimingTests {
    @Test func closingIsQuickerThanOpening() {
        #expect(DrawerLogic.releaseSpring(velocity: 0, fromDrag: false, from: .compact, to: .dismissed).duration == 0.3)
        #expect(DrawerLogic.releaseSpring(velocity: 0, fromDrag: false, from: .dismissed, to: .compact).duration == 0.4)
        #expect(DrawerLogic.releaseSpring(velocity: 0, fromDrag: false, from: .compact, to: .expanded).duration == 0.4)
    }
}

@Suite("History symbols")
struct HistorySymbolTests {
    private func symbol(_ raw: String, symbology: String = "QR") -> String {
        let summary = ResultLogic.summary(for: PayloadParser.parse(raw), raw: raw, symbology: symbology, canJoinWiFi: false)
        return HistoryLogic.symbol(for: summary, symbology: symbology)
    }

    @Test func eachKindHasItsSymbol() {
        #expect(symbol("https://paystack.com") == "lock")
        #expect(symbol("http://bit.ly/x") == "exclamationmark.triangle")
        #expect(symbol("WIFI:T:WPA;S:Kola;P:x;;") == "wifi")
        #expect(symbol("tel:+234") == "phone")
        #expect(symbol("Gate code 4417") == "text.alignleft")
    }

    @Test func barcodesGetABarcode() {
        #expect(symbol("5901234123457", symbology: "EAN-13") == "barcode")
    }
}

@Suite("Increase Contrast")
struct ContrastTests {
    private func white(_ color: UIColor) -> CGFloat {
        var white: CGFloat = 0
        color.getWhite(&white, alpha: nil)
        return white
    }

    @Test func secondaryTextBrightens() {
        let normal = Palette.secondaryText(contrast: .normal)
        let high = Palette.secondaryText(contrast: .high)
        #expect(abs(white(normal) - white(UIColor(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255, alpha: 1))) < 0.001)
        #expect(abs(white(high) - white(UIColor(red: 0xAE / 255, green: 0xAE / 255, blue: 0xB2 / 255, alpha: 1))) < 0.001)
        #expect(white(high) > white(normal))
    }
}

@Suite("Reduce Motion credit")
struct StillCreditTests {
    @Test func creditIsGoneBeforeTheScannerFadesIn() {
        let still = SplashLogic.StillTimeline()
        for step in 0...200 {
            let t = still.total * Double(step) / 200
            let credit = SplashLogic.stillCreditOpacity(at: t, in: still)
            let scene = SplashLogic.stillSceneOpacity(at: t, in: still)
            #expect(credit == 0 || scene == 0, "credit \(credit) and buttons \(scene) overlap at \(t) s")
        }
        #expect(SplashLogic.stillCreditOpacity(at: still.hold - SplashLogic.stillCreditFade, in: still) == 1)
    }
}

@Suite("Domains wrap at dots")
struct DomainBreakTests {
    @Test func aBreakGoesAfterEachDot() {
        #expect(AddressText.breakingAtDots("paystack.com") == "paystack.\u{200B}com")
        #expect(AddressText.breakingAtDots("a.b.kolapay.ng") == "a.\u{200B}b.\u{200B}kolapay.\u{200B}ng")
        #expect(AddressText.breakingAtDots("Ada Okafor") == "Ada Okafor")
    }

    @Test func titlesBreakAtDotsAndKeepTheUnderline() throws {
        let title = try #require(AddressText.title(LinkSafety.check("https://payst\u{0430}ck.com/pay")))
        #expect(String(title.characters) == "payst\u{0430}ck.\u{200B}com")
        let underlined = title.runs.filter { $0.swiftUI.underlineStyle != nil }.map { String(title[$0.range].characters) }
        #expect(underlined == ["\u{0430}"])
    }
}
