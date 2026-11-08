//
//  ResultAndLayoutTests.swift
//  LensirTests
//
//  Which buttons each kind of code gets, where the brackets and pill go, and
//  how history is grouped and ordered.
//

import CoreGraphics
import Foundation
import Testing
@testable import Lensir

private func summary(_ raw: String, canJoinWiFi: Bool = true, symbology: String? = "QR") -> ResultSummary {
    ResultLogic.summary(for: PayloadParser.parse(raw), raw: raw, symbology: symbology, canJoinWiFi: canJoinWiFi)
}

@Suite("Result sheet")
struct ResultSummaryTests {
    @Test func safeLinkOpensInSafari() {
        let result = summary("https://paystack.com/pay/kola-logistics")
        #expect(result.title == "paystack.com")
        #expect(result.titleIsMonospaced)
        #expect(result.kindLabel == "Link")
        #expect(result.primary == .openLink)
        #expect(result.secondary == .copyLink)
        #expect(result.pillIcon == .lock)
        #expect(!result.isWarning)
    }

    @Test func riskyLinkMakesCopyThePrimary() {
        let result = summary("https://payst\u{0430}ck.com/pay")
        #expect(result.primary == .copyLink)
        #expect(result.secondary == .openAnyway)
        #expect(result.pillIcon == .warning)
        #expect(result.isWarning)
    }

    @Test func scriptLinkHasNoOpenAnyway() {
        let result = summary("javascript:alert(1)")
        #expect(result.primary == .copyLink)
        #expect(result.secondary == nil)
        #expect(result.title == "javascript:")
    }

    @Test func plainHTTPHasNoLock() {
        #expect(summary("http://kolalogistics.ng").pillIcon == .warning)
    }

    @Test func wifiJoinsWhenItCan() {
        let result = summary("WIFI:T:WPA;S:Kola;P:jollof-2026;;")
        #expect(result.primary == .joinWiFi)
        #expect(result.secondary == .copyPassword)
        #expect(result.kindLabel == "Wi-Fi network")
    }

    @Test func wifiFallsBackToCopyPassword() {
        let result = summary("WIFI:T:WPA;S:Kola;P:jollof-2026;;", canJoinWiFi: false)
        #expect(result.primary == .copyPassword)
        #expect(result.secondary == .copyNetworkName)
    }

    @Test func openWifiWithoutJoinCopiesTheName() {
        let result = summary("WIFI:T:nopass;S:Cafe;;", canJoinWiFi: false)
        #expect(result.primary == .copyNetworkName)
        #expect(result.secondary == nil)
    }

    @Test func hiddenNetworkSaysSo() {
        #expect(summary("WIFI:S:Back office;P:12345678;H:true;;").kindLabel == "Hidden Wi-Fi network")
    }

    @Test func eachKindHasItsOwnPrimary() {
        #expect(summary("MECARD:N:Okafor,Ada;TEL:0803;;").primary == .saveContact)
        #expect(summary("tel:+2348031234567").primary == .call)
        #expect(summary("SMSTO:0803:Hi").primary == .sendMessage)
        #expect(summary("mailto:a@b.ng").primary == .email)
        #expect(summary("geo:6.45,3.39").primary == .openMaps)
        #expect(summary("Gate code 4417").primary == .copyText)
    }

    @Test func barcodesSayTheirType() {
        let result = summary("5901234123457", symbology: "EAN-13")
        #expect(result.kindLabel == "Barcode · EAN-13")
        #expect(result.titleIsMonospaced)
    }

    @Test func contactCopyText() {
        let contact = Contact(givenName: "Ada", familyName: "Okafor", organization: "Kola Logistics", jobTitle: "Dispatch",
                              phones: ["0803"], emails: ["ada@kola.ng"])
        #expect(ResultLogic.contactText(contact) == "Ada Okafor\nDispatch, Kola Logistics\n0803\nada@kola.ng")
    }

    @Test func longPillTextIsCut() {
        let result = summary("Gate code 4417. Ring twice and then wait by the blue door.")
        #expect(ResultLogic.pillText(result) == "Gate code 4417. Ring twic…")
        #expect(ResultLogic.pillText(result).count == 26)
    }

    @Test func actionTitles() {
        #expect(ResultAction.openLink.title == "Open in Safari")
        #expect(ResultAction.copyLink.isCopy)
        #expect(!ResultAction.openAnyway.isCopy)
    }
}

@Suite("Brackets and pill")
struct ScanGeometryTests {
    let phone = CGSize(width: 402, height: 874)

    @Test func lookingWindowIsCentredAndCapped() {
        let frame = ScanGeometry.lookingFrame(in: phone)
        #expect(frame.rect.width == 273)
        #expect(frame.rect.width == frame.rect.height)
        #expect(abs(frame.rect.midX - phone.width / 2) <= 0.5)
        #expect(ScanGeometry.lookingFrame(in: CGSize(width: 1024, height: 1366)).rect.width == 280)
    }

    @Test func foundFrameHugsTheCode() {
        let frame = ScanGeometry.foundFrame(around: CGRect(x: 100, y: 200, width: 160, height: 160), in: phone)
        #expect(frame.rect == CGRect(x: 80, y: 180, width: 200, height: 200))
        #expect(frame.cornerRadius == 12)
        #expect(frame.arm == 30)
    }

    @Test func tinyCodesStillGetVisibleBrackets() {
        let frame = ScanGeometry.foundFrame(around: CGRect(x: 100, y: 100, width: 20, height: 20), in: phone)
        #expect(frame.rect.width >= 88 && frame.rect.height >= 88)
        #expect(abs(frame.rect.midX - 110) <= 1)
    }

    @Test func pillSitsUnderTheCode() {
        let center = ScanGeometry.pillCenter(below: CGRect(x: 100, y: 200, width: 200, height: 200), pillSize: CGSize(width: 150, height: 34), in: phone)
        #expect(center == CGPoint(x: 200, y: 433))
        #expect(center.y - 17 - 400 == 16)
    }

    @Test func pillStaysOnScreen() {
        let center = ScanGeometry.pillCenter(below: CGRect(x: -40, y: 200, width: 100, height: 100), pillSize: CGSize(width: 150, height: 34), in: phone)
        #expect(center.x == 91)
    }

    @Test func pillGoesAboveWhenTheCodeIsLow() {
        let center = ScanGeometry.pillCenter(below: CGRect(x: 100, y: 600, width: 200, height: 120), pillSize: CGSize(width: 150, height: 34), in: phone)
        #expect(center.y == 567)
    }

    @Test func dimDeepensAsTheResultOpens() {
        #expect(ScanGeometry.dimOpacity(found: false, sheetOpen: false) < ScanGeometry.dimOpacity(found: true, sheetOpen: false))
        #expect(ScanGeometry.dimOpacity(found: true, sheetOpen: false) < ScanGeometry.dimOpacity(found: true, sheetOpen: true))
    }
}

@Suite("History")
struct HistoryLogicTests {
    struct Item: Equatable { var name: String; var date: Date }

    var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Africa/Lagos")!
        return calendar
    }()
    let locale = Locale(identifier: "en_GB")

    func date(_ day: Int, _ hour: Int, month: Int = 11, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test func newestFirstGroupedByDay() {
        let now = date(8, 12)
        let items = [
            Item(name: "a", date: date(6, 9)),
            Item(name: "b", date: date(8, 9)),
            Item(name: "c", date: date(7, 22)),
            Item(name: "d", date: date(8, 11)),
            Item(name: "e", date: date(6, 18)),
        ]
        let sections = HistoryLogic.sections(items, date: \.date, now: now, calendar: calendar, locale: locale)
        #expect(sections.map(\.title) == ["Today", "Yesterday", "Friday 6 November"])
        #expect(sections.map { $0.items.map(\.name) } == [["d", "b"], ["c"], ["e", "a"]])
    }

    @Test func lastYearShowsTheYear() {
        let sections = HistoryLogic.sections([Item(name: "a", date: date(24, 10, month: 12, year: 2025))], date: \.date,
                                             now: date(8, 12), calendar: calendar, locale: locale)
        #expect(sections.first?.title == "Wednesday, 24 December 2025")
    }

    @Test func emptyHistoryHasNoSections() {
        #expect(HistoryLogic.sections([Item](), date: \.date, now: date(8, 12), calendar: calendar, locale: locale).isEmpty)
    }

    @Test func repeatScansAreMerged() {
        let now = date(8, 12)
        #expect(HistoryLogic.isRepeat(payload: "x", at: now, lastPayload: "x", lastDate: now.addingTimeInterval(-30)))
        #expect(!HistoryLogic.isRepeat(payload: "x", at: now, lastPayload: "x", lastDate: now.addingTimeInterval(-90)))
        #expect(!HistoryLogic.isRepeat(payload: "x", at: now, lastPayload: "y", lastDate: now.addingTimeInterval(-5)))
        #expect(!HistoryLogic.isRepeat(payload: "x", at: now, lastPayload: nil, lastDate: nil))
    }
}

@Suite("System links")
struct ResultLinksTests {
    @Test func call() {
        #expect(ResultLinks.call("+234 803 123-4567")?.absoluteString == "tel:+2348031234567")
    }

    @Test func message() {
        #expect(ResultLinks.message(to: "0803 123 4567", body: "Pay ₦5,000 & go")?.absoluteString == "sms:08031234567&body=Pay%20%E2%82%A65,000%20%26%20go")
        #expect(ResultLinks.message(to: "0803", body: "")?.absoluteString == "sms:0803")
    }

    @Test func email() {
        #expect(ResultLinks.email(to: "hello@kola.ng", subject: "Order 412", body: "")?.absoluteString == "mailto:hello@kola.ng?subject=Order%20412")
    }

    @Test func maps() {
        #expect(ResultLinks.maps(Location(latitude: 6.4541, longitude: 3.3947, query: "Kola Logistics"))?.absoluteString == "maps://?ll=6.454100,3.394700&q=Kola%20Logistics")
    }

    @Test func webKeepsLookalikesIntact() {
        #expect(ResultLinks.web("https://paystack.com/pay")?.host() == "paystack.com")
        #expect(ResultLinks.web("https://payst\u{0430}ck.com/pay") != nil)
    }
}
