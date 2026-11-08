//
//  ScanLinkTests.swift
//  LensirTests
//
//  Getting to the scanner in one move: reading lensir://scan, every entry
//  point landing in the same inbox, what the link closes, and the short
//  opening animation it plays on a cold launch.
//

import AppIntents
import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import Lensir

@Suite("lensir:// links")
struct LensirLinkTests {
    @Test(arguments: [
        "lensir://scan",
        "lensir://scan/",
        "LENSIR://SCAN",
        "lensir://scan?from=widget",
        "lensir://scan#now",
        "lensir:scan",
    ])
    func readsScan(_ text: String) throws {
        let url = try #require(URL(string: text))
        #expect(LensirLink(url: url) == .scan)
    }

    @Test(arguments: [
        "lensir://",
        "lensir://history",
        "lensir://scan/photo",
        "lensir://scanner",
        "https://scan",
        "tape://scan",
        "scan",
    ])
    func ignoresAnythingElse(_ text: String) throws {
        let url = try #require(URL(string: text))
        #expect(LensirLink(url: url) == nil)
    }

    @Test func roundTrips() {
        #expect(LensirLink.scan.url.absoluteString == "lensir://scan")
        #expect(LensirLink(url: LensirLink.scan.url) == .scan)
    }

    /// The scheme the app answers to is the one the widget opens.
    @Test func infoPlistRegistersTheScheme() throws {
        let plist = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Config/Lensir-Info.plist")
        let data = try Data(contentsOf: plist)
        let info = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let types = try #require(info["CFBundleURLTypes"] as? [[String: Any]])
        let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        #expect(schemes == [LensirLink.scheme])
    }
}

@MainActor
@Suite("Ways into the scanner")
struct LinkInboxTests {
    @Test func aLinkLandsInTheInbox() throws {
        let inbox = LinkInbox()
        #expect(inbox.receive(try #require(URL(string: "lensir://scan"))))
        #expect(inbox.latest == LinkInbox.Request(link: .scan, number: 1))
    }

    @Test func anUnknownLinkChangesNothing() throws {
        let inbox = LinkInbox()
        #expect(!inbox.receive(try #require(URL(string: "lensir://elsewhere"))))
        #expect(inbox.latest == nil)
    }

    /// Asking twice is two requests, so the second still closes whatever
    /// was opened in between.
    @Test func everyRequestIsNew() {
        let inbox = LinkInbox()
        inbox.receive(.scan)
        let first = inbox.latest
        inbox.receive(.scan)
        #expect(inbox.latest != first)
        #expect(inbox.latest?.number == 2)
    }

    /// The control, the Action Button and Siri run the intent; it lands in
    /// the same place as the widget's link.
    @Test func theIntentAsksForTheScanner() async throws {
        let before = LinkInbox.shared.latest?.number ?? 0
        _ = try await OpenScannerIntent().perform()
        #expect(LinkInbox.shared.latest?.link == .scan)
        #expect(LinkInbox.shared.latest?.number == before + 1)
    }

    @Test func theIntentOpensTheApp() {
        #expect(OpenScannerIntent.supportedModes == .foreground(.immediate))
    }

    @Test func siriHasOneShortcut() {
        #expect(LensirShortcuts.appShortcuts.count == 1)
    }
}

@Suite("What lensir://scan closes")
struct ScanRoutingTests {
    private func plan(splashDone: Bool = true, splashStarted: Bool = true, hasResult: Bool = false,
                      showingHistory: Bool = false, showingPhotoList: Bool = false) -> ScanRouting.Plan {
        ScanRouting.plan(for: .scan, splashDone: splashDone, splashStarted: splashStarted, hasResult: hasResult,
                         showingHistory: showingHistory, showingPhotoList: showingPhotoList)
    }

    @Test func alreadyOnTheScannerDoesNothing() {
        #expect(plan() == ScanRouting.Plan(splash: .none, closeDrawer: false, closeHistory: false, closePhotoList: false))
    }

    @Test func closesWhateverIsOpen() {
        #expect(plan(hasResult: true).closeDrawer)
        #expect(plan(showingHistory: true).closeHistory)
        #expect(plan(showingPhotoList: true).closePhotoList)
        let everything = plan(hasResult: true, showingHistory: true, showingPhotoList: true)
        #expect(everything.closeDrawer && everything.closeHistory && everything.closePhotoList)
    }

    @Test func coldLaunchPlaysTheShortVersion() {
        #expect(plan(splashDone: false, splashStarted: false).splash == .quick)
    }

    @Test func lateLinkSkipsTheOpening() {
        #expect(plan(splashDone: false, splashStarted: true).splash == .skip)
    }
}

@Suite("Short opening")
struct QuickSplashTests {
    private let screen = CGSize(width: 402, height: 874)
    private let quick = SplashLogic.Timeline.quick

    @Test func isShorterThanHalfTheFullOne() {
        #expect(quick.total <= SplashLogic.Timeline().total / 2)
        #expect(!quick.hasLock)
        #expect(SplashLogic.Timeline().hasLock)
    }

    /// The first frame is the launch screen's mark, so nothing jumps.
    @Test func startsOnTheLaunchMark() {
        let first = SplashLogic.brackets(at: 0, in: quick, screen: screen)
        #expect(first.frame == SplashLogic.markFrame(screen: screen))
        #expect(first.stroke == SplashLogic.Mark.stroke)
    }

    @Test func endsOnTheScannersBrackets() {
        let last = SplashLogic.brackets(at: quick.total, in: quick, screen: screen)
        #expect(last.frame == ScanGeometry.lookingFrame(in: screen))
        #expect(last.stroke == SplashLogic.scannerStroke)
    }

    @Test func onlyGrows() {
        var previous: CGFloat = 0
        for step in 0...30 {
            let side = SplashLogic.brackets(at: quick.total * Double(step) / 30, in: quick, screen: screen).frame.rect.width
            #expect(side >= previous)
            previous = side
        }
    }

    @Test func noCreditNoRing() {
        for step in 0...20 {
            let t = quick.total * Double(step) / 20
            #expect(SplashLogic.creditOpacity(at: t, in: quick) == 0)
            #expect(SplashLogic.ring(at: t, in: quick).opacity == 0)
            #expect(SplashLogic.dotScale(at: t, in: quick) == 1)
        }
        let still = SplashLogic.StillTimeline.quick
        for step in 0...20 {
            #expect(SplashLogic.stillCreditOpacity(at: still.total * Double(step) / 20, in: still) == 0)
        }
    }

    @Test func sceneIsInByTheEnd() {
        #expect(SplashLogic.sceneOpacity(at: 0, in: quick) == 0)
        #expect(SplashLogic.sceneOpacity(at: quick.total, in: quick) == 1)
    }
}

@MainActor
@Suite("History store")
struct HistoryStoreTests {
    /// The widget brought an App Group. SwiftData would follow it into the
    /// group by default, and history already on the phone would be left behind.
    @Test func staysInTheAppsOwnContainer() throws {
        let container = LensirStore.makeContainer()
        let url = try #require(container.configurations.first?.url)
        #expect(!url.path().contains("/AppGroup/"))
    }
}
