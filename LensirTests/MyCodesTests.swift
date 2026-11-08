//
//  MyCodesTests.swift
//  LensirTests
//
//  My codes: keeping, renaming, the row's line, the brightness while a code
//  is shown, the Make drawer's one height, where VoiceOver lands when it
//  closes, the tick on Keep, and the store My codes shares with History.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import Lensir

@Suite("My codes")
struct MyCodesLogicTests {
    @Test func keepingANewCodeAddsIt() {
        #expect(MyCodesLogic.keep(raw: "tel:+2348060000000", name: " Front desk ", keptPayloads: []) == .insert(name: "Front desk"))
    }

    @Test func keepingTheSameCodeTwiceAddsOneRow() {
        #expect(MyCodesLogic.keep(raw: "tel:+2348060000000", name: "Front desk", keptPayloads: ["tel:+2348060000000"]) == .alreadyKept)
    }

    @Test func aCodeWithNoNameStillGetsOne() {
        #expect(MyCodesLogic.keep(raw: "x", name: "  ", keptPayloads: []) == .insert(name: "My code"))
    }

    @Test func renaming() {
        #expect(MyCodesLogic.renamed(current: "Kola Logistics", to: "  Office Wi-Fi ") == "Office Wi-Fi")
        #expect(MyCodesLogic.renamed(current: "Kola Logistics", to: "   ") == "Kola Logistics")
        #expect(MyCodesLogic.renamed(current: "a", to: String(repeating: "b", count: 80)).count == MyCodesLogic.nameLimit)
    }

    @Test func rowSaysKindAndDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Lagos")!
        let locale = Locale(identifier: "en_GB")
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))!
        let made = calendar.date(from: DateComponents(year: 2026, month: 11, day: 6, hour: 9))!
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 3, day: 2, hour: 9))!
        #expect(MyCodesLogic.subtitle(raw: "WIFI:T:WPA;S:Kola;P:jollof-2026;;", date: made, now: now, calendar: calendar, locale: locale) == "Wi-Fi · 6 Nov")
        #expect(MyCodesLogic.subtitle(raw: "https://kolalogistics.test", date: lastYear, now: now, calendar: calendar, locale: locale) == "Link · 2 Mar 2025")
    }
}

@Suite("Brightness while a code shows")
struct BrightnessLockTests {
    @Test func raisesThenRestoresWhatYouHad() {
        var lock = BrightnessLock()
        #expect(lock.raise(from: 0.35) == 1)
        #expect(lock.restore() == 0.35)
        #expect(lock.restore() == nil)
    }

    @Test func raisingTwiceKeepsTheFirstBrightness() {
        var lock = BrightnessLock()
        _ = lock.raise(from: 0.35)
        #expect(lock.raise(from: 1) == nil)
        #expect(lock.restore() == 0.35)
    }

    @Test func leavingAndComingBackDoesNotRatchet() {
        var lock = BrightnessLock()
        _ = lock.raise(from: 0.4)
        #expect(lock.restore() == 0.4)   // left the app
        #expect(lock.raise(from: 0.4) == 1)  // came back
        #expect(lock.restore() == 0.4)   // closed the code
    }

    @Test func restoringWithoutRaisingDoesNothing() {
        var lock = BrightnessLock()
        #expect(lock.restore() == nil)
    }
}

@Suite("The Make drawer")
struct MakeDrawerLogicTests {
    @Test func oneHeightOnly() {
        // A throw upward would expand a result drawer; Make stays put.
        #expect(DrawerLogic.snap(height: 500, velocity: 1500, compact: 500, expanded: 500, from: .compact, expands: false) == .compact)
        #expect(DrawerLogic.snap(height: 500, velocity: 1500, compact: 300, expanded: 700, from: .compact) == .expanded)
    }

    @Test func stillClosesOnAFlickDown() {
        #expect(DrawerLogic.snap(height: 480, velocity: -1500, compact: 500, expanded: 500, from: .compact, expands: false) == .dismissed)
        #expect(DrawerLogic.snap(height: 120, velocity: 0, compact: 500, expanded: 500, from: .compact, expands: false) == .dismissed)
    }

    @Test func voiceOverGoesBackToMake() {
        #expect(ScannerFocusLogic.afterClosing(.make, hint: "Point at a QR code") == .makeButton)
        #expect(ScannerFocusLogic.afterClosing(.make, hint: nil) == .makeButton)
        #expect(ScannerFocusLogic.afterClosing(.result, hint: "Point at a QR code") == .hint)
        #expect(ScannerFocusLogic.afterClosing(.result, hint: nil) == .photoButton)
    }

    @Test func keepTicksOnceAndOnlyWithHapticsOn() {
        #expect(HapticLogic.feedback(for: .kept, hapticsOn: true) == .impact(weight: .light))
        #expect(HapticLogic.feedback(for: .kept, hapticsOn: false) == nil)
    }

    @Test func demoScenesOpenFilledIn() {
        #expect(DemoScene.makeWiFi.makeDraft?.kind == .wifi)
        #expect(DemoScene.makeRisky.makeDraft.flatMap(CodeMaker.safety(for:))?.isSafe == false)
        #expect(DemoScene.makeLink.makeDraft.flatMap(CodeMaker.safety(for:))?.isSafe == true)
        #expect(DemoScene.makeLink.payload == nil && !DemoScene.makeLink.opensSheet)
    }
}

@MainActor
@Suite("My codes store")
struct MyCodesStoreTests {
    @Test func sharesTheHistoryStore() throws {
        let container = LensirStore.makeContainer()
        let names = Set(container.schema.entities.map(\.name))
        #expect(names.isSuperset(of: ["ScanRecord", "MadeCode"]))
        #expect(container.configurations.count == 1)
        let url = try #require(container.configurations.first?.url)
        #expect(!url.path().contains("/AppGroup/"))
    }

    @Test func keepsAndRenamesCodes() throws {
        let container = try ModelContainer(for: ScanRecord.self, MadeCode.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let code = MadeCode(raw: "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;", name: "Kola Logistics")
        context.insert(code)
        context.insert(ScanRecord(raw: "https://kolalogistics.test", symbology: "QR"))
        try context.save()
        code.name = MyCodesLogic.renamed(current: code.name, to: "Office Wi-Fi")
        try context.save()
        let codes = try context.fetch(FetchDescriptor<MadeCode>())
        #expect(codes.map(\.name) == ["Office Wi-Fi"])
        // Clearing History leaves My codes alone.
        try context.delete(model: ScanRecord.self)
        #expect(try context.fetchCount(FetchDescriptor<MadeCode>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<ScanRecord>()) == 0)
    }
}
