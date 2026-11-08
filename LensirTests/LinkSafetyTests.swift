//
//  LinkSafetyTests.swift
//  LensirTests
//
//  Every safety rule, the exact letters each lookalike underlines, and the
//  real sites that must come through clean.
//

import Testing
@testable import Lensir

private func kinds(_ raw: String) -> [SafetyFinding.Kind] {
    LinkSafety.check(raw).findings.map(\.kind)
}

/// The underlined text, read back out of displayHost.
private func underlined(_ raw: String) -> [String] {
    let report = LinkSafety.check(raw)
    let host = Array(report.address?.displayHost ?? "")
    return report.highlights.map { String(host[$0]) }
}

@Suite("Real sites pass")
struct NoFalsePositiveTests {
    @Test(arguments: [
        "https://paystack.com", "https://paystack.com/pay/kola-logistics", "https://checkout.paystack.com/abc",
        "https://paystack.co/", "https://gtbank.com", "https://www.gtbank.com/personal", "https://google.com",
        "https://www.google.com/search?q=lagos", "https://mail.google.com", "https://google.com.ng",
        "https://flutterwave.com", "https://opayweb.com", "https://palmpay.com", "https://moniepoint.com",
        "https://kuda.com", "https://www.accessbankplc.com", "https://zenithbank.com", "https://firstbanknigeria.com",
        "https://www.ubagroup.com", "https://stanbicibtc.com", "https://fidelitybank.ng", "https://sterling.ng",
        "https://wemabank.com", "https://alat.ng", "https://www.jumia.com.ng", "https://konga.com", "https://mtn.ng",
        "https://airtel.com.ng", "https://gloworld.com", "https://dstv.com", "https://gotvafrica.com",
        "https://ikejaelectric.com", "https://ekedp.com", "https://jamb.gov.ng", "https://firs.gov.ng",
        "https://nimc.gov.ng", "https://paypal.com", "https://www.apple.com", "https://icloud.com",
        "https://gmail.com", "https://wa.me/2348031234567", "https://www.whatsapp.com", "https://instagram.com",
        "https://facebook.com", "https://fb.com", "https://microsoft.com", "https://login.microsoftonline.com",
        "https://netflix.com", "https://amazon.com", "https://amazon.co.uk", "https://amazon.de", "https://binance.com",
        "https://github.com", "https://en.wikipedia.org/wiki/Lagos", "https://youtube.com/watch?v=1",
        "https://devakintola.com", "https://cloud.com", "https://finance.yahoo.com", "https://apply.com",
        "https://nextcloud.com", "https://www.bbc.co.uk/news", "https://office365.com", "https://googleusercontent.com",
        "https://my-shop.myshopify.com", "https://example.com:8443/path",
    ])
    func passes(_ raw: String) {
        let report = LinkSafety.check(raw)
        #expect(report.findings.isEmpty, "\(raw): \(report.findings.map(\.message))")
    }

    @Test func knownBrandSaysSo() {
        #expect(LinkSafety.check("https://paystack.com/pay").safeSummary == "Secure · the real paystack.com")
        #expect(LinkSafety.check("https://checkout.paystack.com").owner?.mainDomain == "paystack.com")
        #expect(LinkSafety.check("https://kolalogistics.ng").safeSummary == "Secure · nothing odd in the address")
    }
}

@Suite("Scheme rules")
struct SchemeRuleTests {
    @Test func httpIsNotSecure() {
        #expect(kinds("http://kolalogistics.ng") == [.notHTTPS])
    }

    @Test func javascriptAndDataCantBeOpened() {
        let script = LinkSafety.check("javascript:alert(document.cookie)")
        #expect(script.findings.map(\.kind) == [.script])
        #expect(!script.canOpen)
        let data = LinkSafety.check("data:text/html;base64,PGgxPkhpPC9oMT4=")
        #expect(data.findings.map(\.kind) == [.script])
        #expect(!data.canOpen)
    }

    @Test func safeLinkCanOpen() {
        #expect(LinkSafety.check("https://paystack.com").canOpen)
    }
}

@Suite("Address rules")
struct AddressRuleTests {
    @Test(arguments: ["https://bit.ly/3kQ9xZp", "https://tinyurl.com/abc", "https://t.co/x", "https://goo.gl/x",
                      "https://ow.ly/x", "https://is.gd/x", "https://buff.ly/x", "https://cutt.ly/x",
                      "https://rebrand.ly/x", "https://shorturl.at/x", "https://rb.gy/x", "https://qrco.de/x"])
    func shorteners(_ raw: String) {
        #expect(kinds(raw) == [.shortener])
    }

    @Test(arguments: ["https://192.168.0.1/login", "http://3232235521/", "http://0xC0A80001/", "https://[2001:db8::1]/"])
    func ipAddresses(_ raw: String) {
        #expect(kinds(raw).contains(.ipAddress))
    }

    @Test func atSignHidesTheRealSite() {
        let report = LinkSafety.check("https://paystack.com@evil-pay.xyz/login")
        #expect(report.address?.registrableDomain == "evil-pay.xyz")
        #expect(report.findings.map(\.kind).contains(.userInfo))
        #expect(report.findings.first { $0.kind == .userInfo }?.message.contains("evil-pay.xyz") == true)
    }

    @Test func manySubdomains() {
        #expect(kinds("https://login.secure.account.verify.kolapay.com").contains(.manySubdomains))
        #expect(!kinds("https://a.b.c.kolapay.com").contains(.manySubdomains))
    }

    @Test(arguments: ["https://x7k2p9q4m1z8w3.top", "https://qwrtzpsdfghjkl.com", "https://a8f3k9d2m4n7.ngrok.io"])
    func randomNames(_ raw: String) {
        #expect(kinds(raw).contains(.randomName))
    }

    @Test(arguments: ["firstbanknigeria", "ikejaelectric", "microsoftonline", "kolalogistics", "office365online"])
    func ordinaryLongNamesArentRandom(_ label: String) {
        #expect(!LinkSafety.looksRandom(label))
    }

    @Test func backslashesCountAsSlashes() {
        #expect(LinkSafety.check("https://paystack.com\\@evil.xyz").address?.host == "paystack.com")
    }

    @Test func percentEncodedHostIsDecoded() {
        #expect(LinkSafety.check("https://%70aystack.com").address?.host == "paystack.com")
    }
}

@Suite("Lookalikes")
struct LookalikeTests {
    @Test func cyrillicLetterIsUnderlinedAndNamed() {
        let raw = "https://payst\u{0430}ck.com/pay"
        let report = LinkSafety.check(raw)
        #expect(report.findings.map(\.kind) == [.mixedScript, .lookalike])
        #expect(report.findings[0].message == "The underlined “\u{0430}” is a Cyrillic letter, so this is not paystack.com.")
        #expect(report.findings[1].message == "Made to look like a site you know.")
        #expect(underlined(raw) == ["\u{0430}"])
        #expect(report.highlights == [5..<6])
    }

    @Test func punycodeIsDecodedThenCaught() {
        // xn--pystack-2fg.com is "pаystack.com" with a Cyrillic а.
        let report = LinkSafety.check("https://xn--pystack-2fg.com")
        #expect(report.address?.displayHost == "p\u{0430}ystack.com")
        #expect(report.findings.map(\.kind).contains(.mixedScript))
        #expect(report.findings[0].message.hasSuffix("so this is not paystack.com."))
        #expect(underlined("https://xn--pystack-2fg.com") == ["\u{0430}"])
    }

    @Test func greekOmicron() {
        let raw = "https://g\u{03BF}\u{03BF}gle.com"
        #expect(kinds(raw).contains(.mixedScript))
        #expect(underlined(raw) == ["\u{03BF}", "\u{03BF}"])
        #expect(LinkSafety.check(raw).findings[0].message == "The underlined letters aren't plain English letters, so this is not google.com.")
    }

    @Test func numberOneForL() {
        let raw = "https://paypa1.com/signin"
        let report = LinkSafety.check(raw)
        #expect(report.findings.map(\.kind) == [.lookalike, .lookalike])
        #expect(report.findings[0].message == "The underlined “1” is the number one, not an “l”, so this is not paypal.com.")
        #expect(underlined(raw) == ["1"])
    }

    @Test func zeroForO() {
        #expect(LinkSafety.check("https://g00gle.com").findings[0].message == "The underlined “00” is two zeros, not “oo”, so this is not google.com.")
        #expect(underlined("https://g00gle.com") == ["00"])
    }

    @Test func rnForM() {
        let raw = "https://rnicrosoft.com"
        #expect(LinkSafety.check(raw).findings[0].message == "The underlined “rn” is “r” and “n” side by side, not an “m”, so this is not microsoft.com.")
        #expect(underlined(raw) == ["rn"])
    }

    @Test func capitalIForL() {
        // Hosts are lower-cased, so paypaI.com arrives as paypai.com.
        #expect(LinkSafety.check("https://paypaI.com").findings.first?.message == "The underlined “i” should be “l”, so this is not paypal.com.")
    }

    @Test func typoOfALongName() {
        #expect(LinkSafety.check("https://paystak.com").findings.first?.message == "It's missing a letter from paystack.com, so this is not that site.")
        #expect(underlined("https://gtbanc.com") == ["c"])
        #expect(kinds("https://flutterwavve.com").contains(.lookalike))
        #expect(kinds("https://paytsack.com").contains(.lookalike))
        #expect(kinds("https://moniepont.com").contains(.lookalike))
    }

    @Test(arguments: ["https://paystack-login.com", "https://gtbank-ng.com", "https://secure-opay.ng", "https://mtn-promo.com", "https://paystackverify.com"])
    func borrowedNames(_ raw: String) {
        #expect(kinds(raw) == [.lookalike])
        #expect(LinkSafety.check(raw).findings[0].message.hasPrefix("This is not"))
    }

    @Test func brandInASubdomain() {
        let report = LinkSafety.check("https://paystack.com.pay-now.xyz/kola")
        #expect(report.findings.map(\.kind) == [.lookalike])
        #expect(report.findings[0].message == "This is not paystack.com. “paystack” is only at the start; the site is really pay-now.xyz.")
    }

    @Test func brandNameOnFreeHosting() {
        #expect(LinkSafety.check("https://paystack.vercel.app").findings.first?.message == "This uses the name “paystack”, but the real site is paystack.com.")
        #expect(kinds("https://gtbank.xyz") == [.lookalike])
    }

    @Test func wholeCyrillicNameIsFlagged() {
        let report = LinkSafety.check("https://\u{0430}\u{0440}\u{0440}\u{04CF}\u{0435}.com")
        #expect(report.findings.map(\.kind).contains(.otherAlphabet))
        #expect(report.findings.map(\.kind).contains(.lookalike))
    }

    @Test func accentedLetter() {
        #expect(underlined("https://paystáck.com") == ["á"])
    }
}

@Suite("Helpers")
struct SafetyHelperTests {
    @Test func punycode() {
        #expect(Punycode.decode("pystack-2fg") == "p\u{0430}ystack")
        #expect(Punycode.decode("mnchen-3ya") == "münchen")
        #expect(Punycode.decodeHost("xn--mnchen-3ya.de") == "münchen.de")
        #expect(Punycode.decode("!!!") == nil)
    }

    @Test func skeleton() {
        #expect(Confusables.skeleton("p\u{0430}ypa1") == Confusables.skeleton("paypal"))
        #expect(Confusables.skeleton("rnicrosoft") == Confusables.skeleton("microsoft"))
        #expect(Confusables.skeleton("ｐａｙｐａｌ") == Confusables.skeleton("paypal"))
    }

    @Test func editDistance() {
        #expect(LinkSafety.editDistance("paystack", "paystack") == 0)
        #expect(LinkSafety.editDistance("paystack", "paytsack") == 1)
        #expect(LinkSafety.editDistance("paystack", "paystak") == 1)
        #expect(LinkSafety.editDistance("kitten", "sitting") == 3)
    }

    @Test func difference() {
        #expect(LinkSafety.difference("paypa1", "paypal") == ("1", "l", 5..<6) )
        #expect(LinkSafety.difference("paystak", "paystack").0 == "")
    }

    @Test func registrableDomain() {
        #expect(LinkAddress.split("a.b.jumia.com.ng").0 == "jumia.com.ng")
        #expect(LinkAddress.split("a.b.jumia.com.ng").1 == ["a", "b"])
        #expect(LinkAddress.split("kola.vercel.app").0 == "kola.vercel.app")
        #expect(LinkAddress.split("site.sites.google.com").0 == "site.sites.google.com")
    }

    @Test func addressParts() throws {
        let address = try #require(LinkAddress("HTTPS://user:pw@WWW.Paystack.com:443/pay?x=1#top"))
        #expect(address.scheme == "https")
        #expect(address.userInfo == "user:pw")
        #expect(address.host == "www.paystack.com")
        #expect(address.port == "443")
        #expect(address.rest == "/pay?x=1#top")
        #expect(address.shortHost == "paystack.com")
        #expect(address.shortHostOffset == 4)
        #expect(address.subdomains == ["www"])
    }
}
