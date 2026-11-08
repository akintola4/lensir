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
        #expect(DrawerLogic.height(start: expanded, translation: -5000, expanded: expanded) < expanded + DrawerLogic.rubberBandLimit)
        #expect(DrawerLogic.rubberBand(offset: 0) == 0)
        #expect(DrawerLogic.rubberBand(offset: -40) == 0)
    }

    @Test func rubberBandGivesLessTheFurtherItGoes() {
        let first = DrawerLogic.rubberBand(offset: 50)
        let second = DrawerLogic.rubberBand(offset: 100) - first
        #expect(first < 50 * 0.55)
        #expect(second < first)
        // A make drawer has one height, so it bands past that.
        #expect(DrawerLogic.height(start: compact, translation: -100, expanded: compact) > compact)
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

    @Test func slowDragPastFortyPercentDismisses() {
        // 40% of 360 is 144: let go 150 pt down, standing still.
        #expect(DrawerLogic.shouldDismiss(offset: 150, velocity: 0, compact: compact))
        #expect(!DrawerLogic.shouldDismiss(offset: 130, velocity: 0, compact: compact))
        #expect(DrawerLogic.snap(height: compact - 150, velocity: 0, compact: compact, expanded: expanded, from: .compact) == .dismissed)
        #expect(DrawerLogic.snap(height: compact - 130, velocity: 0, compact: compact, expanded: expanded, from: .compact) == .compact)
    }

    @Test func shortFastFlickDismisses() {
        #expect(DrawerLogic.shouldDismiss(offset: 20, velocity: 600, compact: compact))
        #expect(!DrawerLogic.shouldDismiss(offset: 20, velocity: 400, compact: compact))
        // Moving down fast, but still above compact: not closing.
        #expect(!DrawerLogic.shouldDismiss(offset: -20, velocity: 900, compact: compact))
    }

    @Test func onlyADragBounces() {
        let drag = DrawerLogic.releaseSpring(velocity: 800, fromDrag: true, from: .compact, to: .expanded)
        #expect(drag == DrawerSpring(duration: 0.4, bounce: DrawerLogic.dragBounce, velocity: 800))
        // The grabber tapped, a button, VoiceOver's escape: no force, no bounce, no speed.
        let tap = DrawerLogic.releaseSpring(velocity: 800, fromDrag: false, from: .compact, to: .expanded)
        #expect(tap == DrawerSpring(duration: 0.4, bounce: 0, velocity: 0))
        // Closing never bounces; it's on its way out.
        #expect(DrawerLogic.releaseSpring(velocity: -900, fromDrag: true, from: .compact, to: .dismissed).bounce == 0)
    }

    @Test func snapBackIsQuick() {
        let back = DrawerLogic.releaseSpring(velocity: -200, fromDrag: true, from: .compact, to: .compact)
        #expect(back.duration == DrawerLogic.snapBackDuration)
        #expect(back.duration < DrawerLogic.openDuration)
    }

    @Test func wildFlicksAreCapped() {
        #expect(DrawerLogic.releaseSpring(velocity: -20_000, fromDrag: true, from: .compact, to: .dismissed).velocity == -DrawerLogic.maxReleaseVelocity)
    }

    @Test func reduceMotionKeepsNoThrowAndNoBounce() {
        let spring = DrawerLogic.releaseSpring(velocity: 1500, fromDrag: true, from: .compact, to: .expanded, reduceMotion: true)
        #expect(spring == DrawerSpring(duration: DrawerLogic.reducedMotionDuration, bounce: 0, velocity: 0))
    }

    @Test func flightStartsAtTheFingersSpeedAndLands() {
        let flight = DrawerFlight(from: compact, to: expanded, spring: DrawerSpring(duration: 0.4, bounce: 0, velocity: 1200))
        let start = DrawerLogic.sample(flight, at: 0)
        #expect(start.height == compact)
        #expect(abs(start.velocity - 1200) < 1)
        let end = DrawerLogic.sample(flight, at: 2)
        #expect(abs(end.height - expanded) < 0.5)
        #expect(DrawerLogic.isSettled(flight, height: end.height, velocity: end.velocity))
    }

    @Test func aThrownSpringOvershootsThenComesBack() {
        let flight = DrawerFlight(from: compact, to: expanded, spring: DrawerSpring(duration: 0.4, bounce: DrawerLogic.dragBounce, velocity: 2500))
        let peak = stride(from: 0.0, through: 1, by: 1.0 / 120).map { DrawerLogic.sample(flight, at: $0).height }.max()!
        #expect(peak > expanded)
        #expect(peak < expanded + 40)
        #expect(DrawerLogic.hasArrived(flight, height: peak))
        #expect(!DrawerLogic.hasArrived(flight, height: 500))
    }

    @Test func dimFollowsProgress() {
        #expect(DrawerLogic.dimOpacity(progress: 0, base: 0.5) == 0.5)
        #expect(abs(DrawerLogic.dimOpacity(progress: 1, base: 0.5) - DrawerLogic.dimMax) < 1e-9)
        #expect(abs(DrawerLogic.dimOpacity(progress: 0.5, base: 0.5) - (0.5 + DrawerLogic.dimMax) / 2) < 1e-9)
        // Rubber-banded past the top, it's no darker than fully open.
        #expect(abs(DrawerLogic.dimOpacity(progress: 1.2, base: 0.5) - DrawerLogic.dimMax) < 1e-9)
        #expect(DrawerLogic.progress(height: 380, expanded: expanded) == 0.5)
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
        #expect(ResultDetails.checks(for: LinkSafety.check("javascript:alert(1)")) == [CheckItem(title: "A web address, not a script or a packed page", passed: false, label: "Web address")])
    }

    @Test func wifiShowsPasswordAndSecurityInCompactAndNothingMore() {
        let wifi = PayloadParser.parse("WIFI:T:WPA;S:Kola;P:jollof-2026;H:true;;")
        #expect(ResultDetails.compactFields(for: wifi) == [
            DetailField(label: "Password", value: "jollof-2026", monospaced: true),
            DetailField(label: "Security", value: "WPA/WPA2"),
        ])
        // The name is the title and "Hidden Wi-Fi network" is the label.
        #expect(ResultDetails.moreFields(for: wifi).isEmpty)
    }

    @Test func contactDetailsAddOnlyWhatCompactLeavesOut() {
        let contact = PayloadParser.parse("MECARD:N:Okafor,Ada;TEL:0803;TEL:0701;TEL:0909;EMAIL:ada@kola.ng;ORG:Kola;URL:https://kola.ng;ADR:Ikeja;NOTE:Driver;;")
        #expect(ResultDetails.compactFields(for: contact).map(\.label) == ["Phone", "Phone", "Email", "Work", "Address"])
        #expect(ResultDetails.compactFields(for: contact).map(\.value) == ["0803", "0701", "ada@kola.ng", "Kola", "Ikeja"])
        #expect(ResultDetails.moreFields(for: contact).map(\.label) == ["Phone", "Website", "Note"])
        #expect(ResultDetails.moreFields(for: contact).map(\.value) == ["0909", "https://kola.ng", "Driver"])
    }

    @Test func otherKindsAddOnlyWhatsMissing() {
        #expect(ResultDetails.moreFields(for: .phone("+234")).isEmpty)
        #expect(ResultDetails.moreFields(for: .sms(number: "0803", body: "Hi")).isEmpty)
        #expect(ResultDetails.moreFields(for: .sms(number: "", body: "Hi")) == [DetailField(label: "To", value: "Not given")])
        #expect(ResultDetails.moreFields(for: .email(address: "a@b.ng", subject: "S", body: "B")).isEmpty)
        #expect(ResultDetails.compactFields(for: .email(address: "a@b.ng", subject: "S", body: "B")).map(\.label) == ["Subject", "Message"])
        #expect(ResultDetails.compactFields(for: .location(Location(latitude: 6.45, longitude: 3.39, query: "Office"))).map(\.label) == ["Coordinates"])
        #expect(ResultDetails.moreFields(for: .location(Location(latitude: 6.45, longitude: 3.39, query: "Office"))).isEmpty)
        #expect(ResultDetails.moreFields(for: .text("Hello")) == [DetailField(label: "Length", value: "5 characters")])
        #expect(ResultDetails.moreFields(for: .link("https://a.com")).isEmpty)
    }

    /// Nothing under Details repeats the title or a compact row.
    @Test(arguments: [
        "WIFI:T:WPA;S:Kola;P:jollof-2026;;",
        "MECARD:N:Okafor,Ada;TEL:0803;EMAIL:ada@kola.ng;ORG:Kola;ADR:Ikeja;;",
        "tel:+2348031234567",
        "SMSTO:0803:See you at six",
        "mailto:ada@kola.ng?subject=Invoice&body=Attached",
        "geo:6.45,3.39?q=Office",
        "https://paystack.com/pay",
        "Gate code 4417",
    ])
    func detailsNeverRepeatTheCompactDrawer(raw: String) {
        let payload = PayloadParser.parse(raw)
        let title = ResultLogic.summary(for: payload, raw: raw, canJoinWiFi: false).title
        let shown = Set(ResultDetails.compactFields(for: payload).map(\.value) + [title])
        #expect(ResultDetails.moreFields(for: payload).allSatisfy { !shown.contains($0.value) })
    }
}

@Suite("Who owns a drag")
struct DragOwnerTests {
    private func start(_ dx: CGFloat, _ dy: CGFloat, handle: Bool = false, offset: CGFloat = 0, canScroll: Bool = true) -> DrawerDrag {
        DrawerLogic.track(DrawerDrag(), translation: CGSize(width: dx, height: dy), startsInHandle: handle, scrollOffset: offset, canScroll: canScroll)
    }

    @Test func smallMovementIsStillATap() {
        #expect(start(3, 5).owner == nil)
    }

    @Test func sidewaysDragsAreLeftAlone() {
        #expect(start(30, 10).owner == .ignored)
    }

    @Test func headerAlwaysMovesTheDrawer() {
        #expect(start(0, 12, handle: true, offset: 300).owner == .drawer)
        #expect(start(0, -12, handle: true, offset: 300).owner == .drawer)
    }

    @Test func dragDownAtTheTopMovesTheDrawer() {
        let drag = start(0, 10, offset: 0)
        #expect(drag.owner == .drawer)
        #expect(drag.drawerTranslation(10) == 0)
        #expect(drag.drawerTranslation(150) == 140)
    }

    @Test func dragDownWhenScrolledScrollsFirst() {
        #expect(start(0, 10, offset: 200).owner == .scroll)
    }

    @Test func scrollHandsOverAtTheTopWithoutAJump() {
        var drag = start(0, 10, offset: 200)
        // Still scrolling back up through the content.
        drag = DrawerLogic.track(drag, translation: CGSize(width: 0, height: 120), startsInHandle: false, scrollOffset: 90, canScroll: true)
        #expect(drag.owner == .scroll)
        // Reached the top 210 pt in: the drawer takes over from there.
        drag = DrawerLogic.track(drag, translation: CGSize(width: 0, height: 210), startsInHandle: false, scrollOffset: 0, canScroll: true)
        #expect(drag.owner == .drawer)
        #expect(drag.drawerTranslation(210) == 0)
        #expect(drag.drawerTranslation(330) == 120)
    }

    @Test func dragUpInCompactExpands() {
        // Compact content doesn't scroll, so the drawer owns any vertical drag.
        #expect(start(0, -20, canScroll: false).owner == .drawer)
    }

    @Test func dragUpWhenExpandedScrolls() {
        #expect(start(0, -20, offset: 0, canScroll: true).owner == .scroll)
    }

    @Test func dragDownWhenContentDoesNotScroll() {
        #expect(start(0, 20, offset: 0, canScroll: false).owner == .drawer)
    }

    @Test func ownerStaysOnceDecided() {
        let drag = DrawerLogic.track(start(30, 5), translation: CGSize(width: 0, height: 200), startsInHandle: false, scrollOffset: 0, canScroll: true)
        #expect(drag.owner == .ignored)
    }
}
