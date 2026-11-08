//
//  DrawerTests.swift
//  LensirTests
//
//  The result drawer: following the finger, the rubber band, which point a
//  release snaps to, the dim and background scale that follow its height,
//  and what the expanded Details section lists.
//

import CoreGraphics
import Testing
@testable import Lensir

@Suite("Drawer physics")
struct DrawerLogicTests {
    let compact: CGFloat = 360
    let expanded: CGFloat = 760

    @Test func followsTheFingerOneToOne() {
        #expect(DrawerLogic.height(start: compact, translation: 100, expanded: expanded) == 260)
        #expect(DrawerLogic.height(start: compact, translation: -200, expanded: expanded) == 560)
    }

    @Test func neverGoesBelowTheEdge() {
        #expect(DrawerLogic.height(start: compact, translation: 900, expanded: expanded) == 0)
    }

    @Test func resistsAboveExpanded() {
        let pulled = DrawerLogic.height(start: expanded, translation: -200, expanded: expanded)
        #expect(pulled > expanded)
        #expect(pulled - expanded < 200 / 2)
        // However far you pull, it gives less than the limit.
        #expect(DrawerLogic.height(start: expanded, translation: -5000, expanded: expanded) < expanded + 120)
        #expect(DrawerLogic.rubberBand(0) == 0)
    }

    @Test func slowReleaseSnapsToTheNearestPoint() {
        #expect(DrawerLogic.snap(height: 340, velocity: 0, compact: compact, expanded: expanded, from: .compact) == .compact)
        #expect(DrawerLogic.snap(height: 600, velocity: 0, compact: compact, expanded: expanded, from: .compact) == .expanded)
        #expect(DrawerLogic.snap(height: 120, velocity: 0, compact: compact, expanded: expanded, from: .compact) == .dismissed)
        #expect(DrawerLogic.snap(height: 520, velocity: 0, compact: compact, expanded: expanded, from: .expanded) == .compact)
    }

    @Test func throwIsProjectedAhead() {
        // Let go at 500 while moving up at 600 pt/s: projected to 620, nearer expanded.
        #expect(DrawerLogic.snap(height: 500, velocity: 600, compact: compact, expanded: expanded, from: .compact) == .expanded)
        // The same spot moving down at 600 pt/s lands nearer compact.
        #expect(DrawerLogic.snap(height: 500, velocity: -600, compact: compact, expanded: expanded, from: .expanded) == .compact)
    }

    @Test func quickFlickDownFromCompactDismisses() {
        // Dragged only 30 pt, but fast.
        #expect(DrawerLogic.snap(height: 330, velocity: -900, compact: compact, expanded: expanded, from: .compact) == .dismissed)
    }

    @Test func flickDownFromExpandedStopsAtCompact() {
        #expect(DrawerLogic.snap(height: 700, velocity: -1500, compact: compact, expanded: expanded, from: .expanded) == .compact)
    }

    @Test func flickUpExpands() {
        #expect(DrawerLogic.snap(height: 380, velocity: 900, compact: compact, expanded: expanded, from: .compact) == .expanded)
    }

    @Test func heightsOfSnapPoints() {
        #expect(DrawerLogic.height(of: .dismissed, compact: compact, expanded: expanded) == 0)
        #expect(DrawerLogic.height(of: .compact, compact: compact, expanded: expanded) == compact)
        #expect(DrawerLogic.height(of: .expanded, compact: compact, expanded: expanded) == expanded)
    }

    @Test func releaseVelocityCarriesIntoTheSpring() {
        #expect(DrawerLogic.relativeVelocity(800, from: 360, to: 760) == 2)
        #expect(DrawerLogic.relativeVelocity(-720, from: 360, to: 0) == 2)
        #expect(DrawerLogic.relativeVelocity(500, from: 360, to: 360) == 0)
    }

    @Test func dimDeepensWithHeight() {
        #expect(DrawerLogic.dimOpacity(height: 0, expanded: expanded, base: 0.5) == 0.5)
        #expect(abs(DrawerLogic.dimOpacity(height: expanded, expanded: expanded, base: 0.5) - 0.7) < 1e-9)
        #expect(abs(DrawerLogic.dimOpacity(height: 380, expanded: expanded, base: 0.5) - 0.6) < 1e-9)
    }

    @Test func backgroundSinksOnlyPastCompact() {
        #expect(DrawerLogic.backgroundScale(height: compact, compact: compact, expanded: expanded) == 1)
        #expect(DrawerLogic.backgroundScale(height: 100, compact: compact, expanded: expanded) == 1)
        #expect(abs(DrawerLogic.backgroundScale(height: expanded, compact: compact, expanded: expanded) - 0.96) < 1e-9)
        #expect(abs(DrawerLogic.backgroundScale(height: 560, compact: compact, expanded: expanded) - 0.98) < 1e-9)
        #expect(DrawerLogic.backgroundRadius(height: expanded, compact: compact, expanded: expanded) == 24)
        #expect(DrawerLogic.backgroundRadius(height: compact, compact: compact, expanded: expanded) == 0)
        #expect(DrawerLogic.expansion(height: 560, compact: compact, expanded: expanded) == 0.5)
    }
}

@Suite("Drawer details")
struct ResultDetailsTests {
    private func checks(_ raw: String) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: ResultDetails.checks(for: LinkSafety.check(raw)).map { ($0.title, $0.passed) })
    }

    @Test func safeLinkPassesEveryCheck() {
        let items = ResultDetails.checks(for: LinkSafety.check("https://paystack.com/pay"))
        #expect(items.count == 9)
        #expect(items.allSatisfy { $0.passed })
        #expect(items.first?.title == "A web address (https:)")
    }

    @Test func lookalikeFailsTheRightRows() {
        let rows = checks("https://payst\u{0430}ck.com/pay")
        #expect(rows["The real site, not a lookalike"] == false)
        #expect(rows["Plain letters, no punycode or mixed alphabets"] == false)
        #expect(rows["Secure connection (https)"] == true)
        #expect(rows["Not a link shortener"] == true)
    }

    @Test func punycodeFailsPlainLetters() {
        #expect(checks("https://xn--pystack-2fg.com")["Plain letters, no punycode or mixed alphabets"] == false)
    }

    @Test func eachRuleHasARow() {
        #expect(checks("http://bit.ly/x")["Secure connection (https)"] == false)
        #expect(checks("http://bit.ly/x")["Not a link shortener"] == false)
        #expect(checks("https://192.168.0.1")["A named site, not a bare IP address"] == false)
        #expect(checks("https://paystack.com@evil.xyz")["No “@” hiding the real site"] == false)
        #expect(checks("https://a.b.c.d.kolapay.com")["A normal number of subdomains"] == false)
        #expect(checks("https://x7k2p9q4m1z8w3.top")["A name that doesn't look made up"] == false)
    }

    @Test func scriptsGetOneFailingRow() {
        #expect(ResultDetails.checks(for: LinkSafety.check("javascript:alert(1)")) == [CheckItem(title: "A web address, not a script or a packed page", passed: false)])
    }

    @Test func wifiFields() {
        #expect(ResultDetails.fields(for: PayloadParser.parse("WIFI:T:WPA;S:Kola;P:jollof-2026;H:true;;")) == [
            DetailField(label: "Network", value: "Kola", monospaced: true),
            DetailField(label: "Password", value: "jollof-2026", monospaced: true),
            DetailField(label: "Security", value: "WPA/WPA2"),
            DetailField(label: "Hidden network", value: "Yes"),
        ])
    }

    @Test func contactListsEveryField() {
        let fields = ResultDetails.fields(for: PayloadParser.parse("MECARD:N:Okafor,Ada;TEL:0803;TEL:0701;EMAIL:ada@kola.ng;ORG:Kola;URL:https://kola.ng;ADR:Ikeja;NOTE:Driver;;"))
        #expect(fields.map(\.label) == ["Name", "Company", "Phone", "Phone", "Email", "Website", "Address", "Note"])
        #expect(fields.map(\.value) == ["Ada Okafor", "Kola", "0803", "0701", "ada@kola.ng", "https://kola.ng", "Ikeja", "Driver"])
    }

    @Test func otherKindsListTheirFields() {
        #expect(ResultDetails.fields(for: .phone("+234")).map(\.label) == ["Number"])
        #expect(ResultDetails.fields(for: .sms(number: "0803", body: "Hi")).map(\.label) == ["To", "Message"])
        #expect(ResultDetails.fields(for: .email(address: "a@b.ng", subject: "S", body: "B")).map(\.label) == ["To", "Subject", "Message"])
        #expect(ResultDetails.fields(for: .location(Location(latitude: 6.45, longitude: 3.39, query: "Office"))).map(\.value) == ["6.450000", "3.390000", "Office"])
        #expect(ResultDetails.fields(for: .text("Hello")) == [DetailField(label: "Length", value: "5 characters")])
        #expect(ResultDetails.fields(for: .link("https://a.com")).isEmpty)
    }
}
