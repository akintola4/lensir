//
//  CodeMakerTests.swift
//  LensirTests
//
//  Making codes: each kind's text, the Wi-Fi escaping, links finished off
//  and checked, and every kind made, parsed back by PayloadParser, and
//  read back off the drawn picture by Vision with the same fields.
//

import CoreGraphics
import Testing
import UIKit
@testable import Lensir

@Suite("Making Wi-Fi codes")
struct MakeWiFiTests {
    @Test func wpaNetwork() {
        #expect(CodeMaker.wifi(ssid: "Kola Logistics", password: "jollof-2026", security: .wpa)
            == .success("WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;"))
    }

    @Test func openNetworkHasNoPassword() {
        #expect(CodeMaker.wifi(ssid: "Kola Guest", password: "ignored", security: .open)
            == .success("WIFI:T:nopass;S:Kola Guest;;"))
    }

    @Test func wpa3AndWEP() {
        #expect(CodeMaker.wifi(ssid: "Kola", password: "jollof-2026", security: .wpa3) == .success("WIFI:T:SAE;S:Kola;P:jollof-2026;;"))
        #expect(CodeMaker.wifi(ssid: "Kola", password: "abcde", security: .wep) == .success("WIFI:T:WEP;S:Kola;P:abcde;;"))
    }

    @Test(arguments: [
        (#"\"#, #"\\"#),
        (";", #"\;"#),
        (",", #"\,"#),
        (":", #"\:"#),
        ("\"", #"\""#),
        (#"Kola;Net, "5G":\x"#, #"Kola\;Net\, \"5G\"\:\\x"#),
        ("plain-name 5G", "plain-name 5G"),
    ])
    func specialCharactersAreEscaped(raw: String, escaped: String) {
        #expect(CodeMaker.escape(raw) == escaped)
    }

    @Test func needsANetworkName() {
        #expect(CodeMaker.wifi(ssid: "  ", password: "jollof-2026", security: .wpa) == .failure(.empty))
    }

    @Test func wpaPasswordNeedsEightCharacters() {
        #expect(CodeMaker.wifi(ssid: "Kola", password: "", security: .wpa) == .failure(.empty))
        #expect(CodeMaker.wifi(ssid: "Kola", password: "jollof", security: .wpa) == .failure(.passwordTooShort(minimum: 8)))
        #expect(CodeMaker.wifi(ssid: "Kola", password: "jollof-2", security: .wpa) == .success("WIFI:T:WPA;S:Kola;P:jollof-2;;"))
    }
}

@Suite("Making links")
struct MakeLinkTests {
    @Test func bareAddressGetsHTTPS() {
        #expect(CodeMaker.link("kolalogistics.test/track") == .success("https://kolalogistics.test/track"))
        #expect(CodeMaker.link("  www.kolalogistics.test \n") == .success("https://www.kolalogistics.test"))
    }

    @Test func typedSchemeIsKept() {
        #expect(CodeMaker.link("http://kolalogistics.test") == .success("http://kolalogistics.test"))
        #expect(CodeMaker.link("HTTPS://kolalogistics.test") == .success("HTTPS://kolalogistics.test"))
    }

    @Test func spacesAndUnfinishedAddressesMakeNothing() {
        #expect(CodeMaker.link("kola logistics.test") == .failure(.linkHasSpaces))
        #expect(CodeMaker.link("kolalogistics") == .failure(.linkIncomplete))
        #expect(CodeMaker.link("kolalogistics.") == .failure(.linkIncomplete))
        #expect(CodeMaker.link("https://") == .failure(.linkIncomplete))
        #expect(CodeMaker.link("") == .failure(.empty))
    }

    @Test func aCleanLinkPassesTheChecks() throws {
        let report = try #require(CodeMaker.safety(for: CodeDraft(kind: .link, link: "kolalogistics.test/track")))
        #expect(report.isSafe)
        #expect(report.safeSummary == "Secure · nothing odd in the address")
    }

    @Test func aLookalikeGetsTheSameWarningAsAScan() throws {
        let typed = "https://payst\u{0430}ck.com/pay"
        let report = try #require(CodeMaker.safety(for: CodeDraft(kind: .link, link: typed)))
        #expect(!report.isSafe)
        #expect(report == LinkSafety.check(typed))
        #expect(report.findings.contains { $0.message.contains("Cyrillic") })
    }

    @Test func httpAndShortLinksWarn() throws {
        let http = try #require(CodeMaker.safety(for: CodeDraft(kind: .link, link: "http://kolalogistics.test")))
        #expect(http.findings.map(\.kind) == [.notHTTPS])
        let short = try #require(CodeMaker.safety(for: CodeDraft(kind: .link, link: "bit.ly/3kQ9xZp")))
        #expect(short.findings.contains { $0.kind == .shortener })
    }

    @Test func scriptsAreKeptAsTypedSoTheyWarn() throws {
        let report = try #require(CodeMaker.safety(for: CodeDraft(kind: .link, link: "javascript:alert(1)")))
        #expect(report.findings.map(\.kind) == [.script])
    }

    @Test func otherKindsHaveNoChecks() {
        #expect(CodeMaker.safety(for: CodeDraft(kind: .wifi, ssid: "Kola", password: "jollof-2026")) == nil)
    }
}

@Suite("Making phone, contact and text codes")
struct MakeOtherKindsTests {
    @Test func phoneKeepsDigitsAndPlus() {
        #expect(CodeMaker.phone("+234 806-000 0000") == .success("tel:+2348060000000"))
        #expect(CodeMaker.phone("12") == .failure(.empty))
    }

    @Test func contactOnlyHasFilledFields() {
        #expect(CodeMaker.contact(name: "Kola Logistics", phone: "+234 806 000 0000", email: "hello@kolalogistics.test")
            == .success("MECARD:N:Kola Logistics;TEL:+2348060000000;EMAIL:hello@kolalogistics.test;;"))
        #expect(CodeMaker.contact(name: "", phone: "", email: "hello@kolalogistics.test")
            == .success("MECARD:EMAIL:hello@kolalogistics.test;;"))
        #expect(CodeMaker.contact(name: " ", phone: "", email: "") == .failure(.empty))
    }

    @Test func textIsTrimmed() {
        #expect(CodeMaker.text("  Gate code 4417.\n") == .success("Gate code 4417."))
        #expect(CodeMaker.text("\n ") == .failure(.empty))
    }

    @Test func tooMuchForOneCode() {
        let draft = CodeDraft(kind: .text, text: String(repeating: "a", count: CodeMaker.capacity + 1))
        #expect(CodeMaker.make(draft) == .failure(.tooLong))
        #expect(CodeMaker.payload(for: CodeDraft(kind: .text, text: String(repeating: "a", count: CodeMaker.capacity))) != nil)
    }

    @Test func eachKindKeepsItsOwnFields() {
        var draft = CodeDraft(kind: .wifi, link: "kolalogistics.test", ssid: "Kola", password: "jollof-2026")
        #expect(CodeMaker.payload(for: draft) == "WIFI:T:WPA;S:Kola;P:jollof-2026;;")
        draft.kind = .link
        #expect(CodeMaker.payload(for: draft) == "https://kolalogistics.test")
    }
}

@Suite("Made codes read back")
struct MakeRoundTripTests {
    static let drafts: [CodeDraft] = [
        CodeDraft(kind: .wifi, ssid: "Kola Logistics", password: "jollof-2026"),
        CodeDraft(kind: .wifi, ssid: #"Kola;Net, "5G":\x"#, password: #"p@ss;w,o:r"d\1"#, security: .wpa3),
        CodeDraft(kind: .wifi, ssid: "Kola Guest", security: .open),
        CodeDraft(kind: .wifi, ssid: "Old Router", password: "abcde", security: .wep),
        CodeDraft(kind: .link, link: "kolalogistics.test/track?parcel=KL-0417"),
        CodeDraft(kind: .phone, phone: "+234 806 000 0000"),
        CodeDraft(kind: .contact, contactName: "Kola Logistics, Ikeja", contactPhone: "+234 806 000 0000", contactEmail: "hello@kolalogistics.test"),
        CodeDraft(kind: .text, text: "Gate code 4417. Ring twice, then wait by the blue door."),
    ]

    /// What the draft says, in the parser's terms.
    static func expected(_ draft: CodeDraft) -> Payload {
        switch draft.kind {
        case .wifi:
            .wifi(WiFi(ssid: draft.ssid, password: draft.security == .open ? nil : draft.password, security: draft.security, hidden: false))
        case .link:
            .link("https://" + draft.link)
        case .phone:
            .phone(ResultLinks.dialable(draft.phone))
        case .contact:
            .contact(Contact(formattedName: draft.contactName, phones: [ResultLinks.dialable(draft.contactPhone)], emails: [draft.contactEmail]))
        case .text:
            .text(draft.text)
        }
    }

    @Test(arguments: drafts)
    func makeThenParseGivesTheSameFields(_ draft: CodeDraft) throws {
        let payload = try #require(CodeMaker.payload(for: draft))
        #expect(PayloadParser.parse(payload) == Self.expected(draft))
        #expect(CodeKind(PayloadParser.parse(payload)) == draft.kind)
    }

    /// The whole way: drawn by CoreImage, read off the picture by Vision,
    /// then parsed.
    @Test(arguments: drafts)
    func theDrawnCodeScansBack(_ draft: CodeDraft) throws {
        let payload = try #require(CodeMaker.payload(for: draft))
        let image = try #require(CodeImage.image(for: payload, atLeast: 600)?.cgImage)
        let codes = PhotoScanner.codes(in: image)
        #expect(codes.map(\.raw) == [payload])
        #expect(codes.first.map { PayloadParser.parse($0.raw) } == Self.expected(draft))
    }
}

@Suite("Drawing codes")
struct CodeImageTests {
    @Test func hasAFourModuleQuietZoneAndHardEdges() throws {
        let image = try #require(CodeImage.modules(for: "https://kolalogistics.test"))
        #expect(image.width == image.height)
        let pixels = try gray(image)
        let side = image.width
        // The quiet zone is white all round.
        for i in 0..<side {
            for ring in 0..<CodeImage.quietZone {
                #expect(pixels[ring * side + i] == 255 && pixels[i * side + ring] == 255)
            }
        }
        // The top-left finder pattern starts right after it, black.
        #expect(pixels[CodeImage.quietZone * side + CodeImage.quietZone] == 0)
        // One pixel per module means only black and white, nothing between.
        #expect(Set(pixels).isSubset(of: [0, 255]))
    }

    @Test func scalingIsNearestNeighbour() throws {
        let modules = try #require(CodeImage.modules(for: "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;"))
        let scaled = try #require(CodeImage.scaled(modules, scale: 9))
        #expect(scaled.width == modules.width * 9)
        #expect(Set(try gray(scaled)).isSubset(of: [0, 255]))
    }

    @Test func sharedPictureIsAtLeastTheSizeAsked() throws {
        let image = try #require(CodeImage.image(for: "tel:+2348060000000", atLeast: 1200))
        #expect(image.size.width >= 1200)
    }

    private func gray(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height)
        let context = try #require(CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: image.width, space: CGColorSpaceCreateDeviceGray(),
                                             bitmapInfo: CGImageAlphaInfo.none.rawValue))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return pixels
    }
}

@Suite("Showing made codes")
struct CodeDisplayTests {
    @Test func wifiSaysHowToJoin() {
        let display = CodeMaker.display(raw: "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;")
        #expect(display.kind == .wifi)
        #expect(display.detail == "Wi-Fi · WPA/WPA2")
        #expect(display.caption == "Point your camera here to join")
        #expect(display.accessibilityLabel == "QR code for Wi-Fi network Kola Logistics")
        #expect(display.monospaced)
    }

    @Test func eachKindHasALabelForVoiceOver() {
        #expect(CodeMaker.display(raw: "https://kolalogistics.test/track").accessibilityLabel == "QR code for link to kolalogistics.test")
        #expect(CodeMaker.display(raw: "tel:+2348060000000").accessibilityLabel == "QR code for phone number +2348060000000")
        #expect(CodeMaker.display(raw: "MECARD:N:Kola Logistics;;").accessibilityLabel == "QR code for contact Kola Logistics")
        #expect(CodeMaker.display(raw: "Gate code 4417").accessibilityLabel == "QR code for text: Gate code 4417")
        #expect(CodeMaker.display(raw: "WIFI:T:nopass;S:Kola Guest;;").detail == "Wi-Fi · no password")
    }

    @Test func defaultNames() {
        #expect(CodeMaker.defaultName(for: CodeDraft(kind: .wifi, ssid: "Kola Logistics")) == "Kola Logistics")
        #expect(CodeMaker.defaultName(for: CodeDraft(kind: .link, link: "www.kolalogistics.test/track")) == "kolalogistics.test")
        #expect(CodeMaker.defaultName(for: CodeDraft(kind: .phone, phone: " +234 806 000 0000")) == "+234 806 000 0000")
        #expect(CodeMaker.defaultName(for: CodeDraft(kind: .contact, contactEmail: "hello@kolalogistics.test")) == "hello@kolalogistics.test")
        #expect(CodeMaker.defaultName(for: CodeDraft(kind: .text, text: "Gate code\nRing twice")) == "Gate code")
        let long = CodeMaker.defaultName(for: CodeDraft(kind: .text, text: String(repeating: "x", count: 60)))
        #expect(long.count == 40 && long.hasSuffix("…"))
    }

    @Test func chipsAreInTheDrawnOrder() {
        #expect(CodeKind.allCases.map(\.title) == ["Wi-Fi", "Link", "Phone", "Contact", "Text"])
    }
}

@Suite("Escaped commas in MECARD names")
struct MecardCommaTests {
    @Test func escapedCommaStaysInTheName() {
        #expect(PayloadParser.parse(#"MECARD:N:Kola Logistics\, Ikeja;;"#) == .contact(Contact(formattedName: "Kola Logistics, Ikeja")))
    }

    @Test func plainCommaStillSplitsFamilyAndGiven() {
        #expect(PayloadParser.parse("MECARD:N:Okafor,Ada;;") == .contact(Contact(givenName: "Ada", familyName: "Okafor")))
    }
}
