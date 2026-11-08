//
//  PayloadParserTests.swift
//  LensirTests
//
//  Every kind of code Lensir reads, with the escaping and odd forms real
//  generators produce.
//

import Testing
@testable import Lensir

@Suite("Links")
struct LinkParsingTests {
    @Test(arguments: [
        "https://paystack.com/pay/kola",
        "http://example.com",
        "HTTPS://EXAMPLE.COM/A",
        "javascript:alert(1)",
        "data:text/html,<h1>hi</h1>",
    ])
    func webAddressesAreLinks(_ raw: String) {
        #expect(PayloadParser.parse(raw) == .link(raw))
    }

    @Test func surroundingWhitespaceIsTrimmed() {
        #expect(PayloadParser.parse("  https://paystack.com \n") == .link("https://paystack.com"))
    }

    @Test func bareWWWGetsHTTP() {
        #expect(PayloadParser.parse("www.konga.com/deals") == .link("http://www.konga.com/deals"))
    }

    @Test func urlPrefixesAreStripped() {
        #expect(PayloadParser.parse("URLTO:https://jumia.com.ng") == .link("https://jumia.com.ng"))
        #expect(PayloadParser.parse("URL:https://jumia.com.ng") == .link("https://jumia.com.ng"))
    }

    @Test func textWithSpacesIsNotALink() {
        #expect(PayloadParser.parse("https://a.com and more") == .text("https://a.com and more"))
    }

    @Test func otherSchemesAreText() {
        #expect(PayloadParser.parse("otpauth://totp/Acme?secret=ABC") == .text("otpauth://totp/Acme?secret=ABC"))
    }
}

@Suite("Wi-Fi")
struct WiFiParsingTests {
    @Test func wpaNetwork() {
        #expect(PayloadParser.parse("WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;")
            == .wifi(WiFi(ssid: "Kola Logistics", password: "jollof-2026", security: .wpa, hidden: false)))
    }

    @Test func fieldsInAnyOrderAndLowerCasePrefix() {
        #expect(PayloadParser.parse("wifi:P:secret;S:Home;T:WEP;H:true;;")
            == .wifi(WiFi(ssid: "Home", password: "secret", security: .wep, hidden: true)))
    }

    @Test func escapedCharactersInSSIDAndPassword() {
        let payload = PayloadParser.parse(#"WIFI:S:My\;Net\:work;T:WPA;P:pa\\ss\;w\,o\"rd;;"#)
        #expect(payload == .wifi(WiFi(ssid: "My;Net:work", password: #"pa\ss;w,o"rd"#, security: .wpa, hidden: false)))
    }

    @Test func openNetworkHasNoPassword() {
        #expect(PayloadParser.parse("WIFI:T:nopass;S:Cafe;P:;;") == .wifi(WiFi(ssid: "Cafe", password: nil, security: .open, hidden: false)))
        #expect(PayloadParser.parse("WIFI:S:Cafe;;") == .wifi(WiFi(ssid: "Cafe", password: nil, security: .open, hidden: false)))
    }

    @Test func missingTypeWithPasswordIsWPA() {
        #expect(PayloadParser.parse("WIFI:S:Home;P:abc12345;;") == .wifi(WiFi(ssid: "Home", password: "abc12345", security: .wpa, hidden: false)))
    }

    @Test func wpa3() {
        #expect(PayloadParser.parse("WIFI:T:SAE;S:Home;P:abc12345;;") == .wifi(WiFi(ssid: "Home", password: "abc12345", security: .wpa3, hidden: false)))
    }

    @Test func missingSSIDIsText() {
        #expect(PayloadParser.parse("WIFI:T:WPA;P:abc;;") == .text("WIFI:T:WPA;P:abc;;"))
    }
}

@Suite("Contacts")
struct ContactParsingTests {
    @Test func mecard() throws {
        guard case .contact(let contact) = PayloadParser.parse("MECARD:N:Okafor,Ada;TEL:+2348031234567;TEL:+2347001234567;EMAIL:ada@kolalogistics.ng;ORG:Kola Logistics;URL:https://kolalogistics.ng;ADR:12 Allen Ave\\, Ikeja;NOTE:Driver;;") else {
            Issue.record("not a contact"); return
        }
        #expect(contact.givenName == "Ada")
        #expect(contact.familyName == "Okafor")
        #expect(contact.displayName == "Ada Okafor")
        #expect(contact.phones == ["+2348031234567", "+2347001234567"])
        #expect(contact.emails == ["ada@kolalogistics.ng"])
        #expect(contact.organization == "Kola Logistics")
        #expect(contact.urls == ["https://kolalogistics.ng"])
        #expect(contact.address == "12 Allen Ave, Ikeja")
        #expect(contact.note == "Driver")
    }

    @Test func mecardWithSingleName() {
        guard case .contact(let contact) = PayloadParser.parse("MECARD:N:Tunde;TEL:0803;;") else { Issue.record("not a contact"); return }
        #expect(contact.displayName == "Tunde")
    }

    @Test func vcard3() {
        let card = """
        BEGIN:VCARD
        VERSION:3.0
        N:Okafor;Ada;;;
        FN:Ada Okafor
        ORG:Kola Logistics;Dispatch
        TITLE:Head of Dispatch
        TEL;TYPE=CELL:+234 803 123 4567
        TEL;TYPE=WORK,VOICE:+234 1 234 5678
        EMAIL;TYPE=INTERNET:ada@kolalogistics.ng
        item1.URL:https://kolalogistics.ng
        ADR;TYPE=WORK:;;12 Allen Ave;Ikeja;Lagos;100271;Nigeria
        NOTE:Call before 6\\, please
        END:VCARD
        """
        guard case .contact(let contact) = PayloadParser.parse(card) else { Issue.record("not a contact"); return }
        #expect(contact.displayName == "Ada Okafor")
        #expect(contact.organization == "Kola Logistics")
        #expect(contact.jobTitle == "Head of Dispatch")
        #expect(contact.phones == ["+234 803 123 4567", "+234 1 234 5678"])
        #expect(contact.emails == ["ada@kolalogistics.ng"])
        #expect(contact.urls == ["https://kolalogistics.ng"])
        #expect(contact.address == "12 Allen Ave, Ikeja, Lagos, 100271, Nigeria")
        #expect(contact.note == "Call before 6, please")
    }

    @Test func vcardFoldedLinesAndCRLF() {
        let card = "BEGIN:VCARD\r\nVERSION:4.0\r\nFN:Chiamaka\r\n  Eze\r\nTEL;VALUE=uri:tel:+2348000000000\r\nEND:VCARD"
        guard case .contact(let contact) = PayloadParser.parse(card) else { Issue.record("not a contact"); return }
        #expect(contact.displayName == "Chiamaka Eze")
        #expect(contact.phones == ["+2348000000000"])
    }

    @Test func nameFallsBackToOrganisation() {
        var contact = Contact()
        contact.organization = "Kola Logistics"
        #expect(contact.displayName == "Kola Logistics")
    }
}

@Suite("Phone, messages, email, places, text")
struct OtherPayloadTests {
    @Test func tel() {
        #expect(PayloadParser.parse("tel:+2348031234567") == .phone("+2348031234567"))
        #expect(PayloadParser.parse("TEL:0803%20123%204567") == .phone("0803 123 4567"))
    }

    @Test func smsto() {
        #expect(PayloadParser.parse("SMSTO:+2348031234567:Hello there: it's me") == .sms(number: "+2348031234567", body: "Hello there: it's me"))
        #expect(PayloadParser.parse("smsto:08031234567") == .sms(number: "08031234567", body: ""))
    }

    @Test func smsURI() {
        #expect(PayloadParser.parse("sms:+2348031234567?body=Pay%20%E2%82%A65000") == .sms(number: "+2348031234567", body: "Pay ₦5000"))
        #expect(PayloadParser.parse("sms:+2348031234567;?&body=Hi") == .sms(number: "+2348031234567", body: "Hi"))
        #expect(PayloadParser.parse("sms:+2348031234567:Hi") == .sms(number: "+2348031234567", body: "Hi"))
    }

    @Test func mailto() {
        #expect(PayloadParser.parse("mailto:hello@kola.ng?subject=Order%20412&body=Call+me")
            == .email(address: "hello@kola.ng", subject: "Order 412", body: "Call+me"))
        #expect(PayloadParser.parse("mailto:?to=a@b.ng") == .email(address: "a@b.ng", subject: "", body: ""))
    }

    @Test func matmsg() {
        #expect(PayloadParser.parse("MATMSG:TO:hello@kola.ng;SUB:Order\\;412;BODY:Thanks;;")
            == .email(address: "hello@kola.ng", subject: "Order;412", body: "Thanks"))
    }

    @Test func geo() {
        #expect(PayloadParser.parse("geo:6.4541,3.3947") == .location(Location(latitude: 6.4541, longitude: 3.3947, query: nil)))
        #expect(PayloadParser.parse("geo:6.4541,3.3947,12?q=Kola%20Logistics") == .location(Location(latitude: 6.4541, longitude: 3.3947, query: "Kola Logistics")))
        #expect(PayloadParser.parse("geo:0,0?q=6.5,3.4(Office)") == .location(Location(latitude: 6.5, longitude: 3.4, query: "Office")))
    }

    @Test func geoOutOfRangeIsText() {
        #expect(PayloadParser.parse("geo:200,3") == .text("geo:200,3"))
    }

    @Test func coordinatesFormat() {
        #expect(Location(latitude: 6.45411, longitude: 3.39467, query: nil).coordinates == "6.4541, 3.3947")
    }

    @Test func plainText() {
        #expect(PayloadParser.parse("Gate code 4417") == .text("Gate code 4417"))
        #expect(PayloadParser.parse("5901234123457") == .text("5901234123457"))
    }
}
