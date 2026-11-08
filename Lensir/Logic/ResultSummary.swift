//
//  ResultSummary.swift
//  Lensir
//
//  Everything the pill and the result sheet say about a code: its title, the
//  small label under it, one main button and one plain one. Every kind of
//  code uses the same sheet; only these change.
//

import Foundation

nonisolated enum ResultAction: Equatable, Sendable {
    case openLink, openAnyway, copyLink
    case joinWiFi, copyPassword, copyNetworkName
    case saveContact, copyContact
    case call, copyNumber
    case sendMessage, copyMessage
    case email, copyEmailAddress
    case openMaps, copyCoordinates
    case copyText

    var title: String {
        switch self {
        case .openLink: "Open in Safari"
        case .openAnyway: "Open anyway"
        case .copyLink: "Copy link"
        case .joinWiFi: "Join Wi-Fi"
        case .copyPassword: "Copy password"
        case .copyNetworkName: "Copy network name"
        case .saveContact: "Save contact"
        case .copyContact: "Copy details"
        case .call: "Call"
        case .copyNumber: "Copy number"
        case .sendMessage: "Send message"
        case .copyMessage: "Copy message"
        case .email: "Write email"
        case .copyEmailAddress: "Copy address"
        case .openMaps: "Open in Maps"
        case .copyCoordinates: "Copy coordinates"
        case .copyText: "Copy text"
        }
    }

    var isCopy: Bool {
        switch self {
        case .copyLink, .copyPassword, .copyNetworkName, .copyContact, .copyNumber,
             .copyMessage, .copyEmailAddress, .copyCoordinates, .copyText: true
        default: false
        }
    }
}

nonisolated struct ResultSummary: Equatable, Sendable {
    enum PillIcon: Equatable, Sendable { case lock, warning, wifi, person, phone, message, envelope, pin, text, none }

    var title: String
    /// Links, numbers, network names and coordinates are set in SF Mono, so
    /// l/1/I and O/0 can't pass for each other.
    var titleIsMonospaced: Bool
    var kindLabel: String
    var primary: ResultAction
    var secondary: ResultAction?
    var pillIcon: PillIcon
    /// For links; nil for everything else.
    var safety: SafetyReport?

    var isWarning: Bool { safety.map { !$0.isSafe } ?? false }

    /// What the copy buttons put on the clipboard, and what Share sends.
    var shareText: String
}

nonisolated enum ResultLogic {
    static func summary(for payload: Payload, raw: String, symbology: String? = nil, canJoinWiFi: Bool) -> ResultSummary {
        switch payload {
        case .link(let link):
            let report = LinkSafety.check(link)
            let title = report.address.map { $0.hasAuthority ? $0.shortHost : $0.scheme + ":" } ?? link
            let warning = !report.isSafe
            return ResultSummary(
                title: title, titleIsMonospaced: true, kindLabel: "Link",
                primary: warning ? .copyLink : .openLink,
                secondary: warning ? (report.canOpen ? .openAnyway : nil) : .copyLink,
                pillIcon: warning ? .warning : (report.address?.scheme == "https" ? .lock : .none),
                safety: report, shareText: link
            )
        case .wifi(let wifi):
            let primary: ResultAction
            let secondary: ResultAction?
            if canJoinWiFi {
                primary = .joinWiFi
                secondary = wifi.password == nil ? .copyNetworkName : .copyPassword
            } else {
                primary = wifi.password == nil ? .copyNetworkName : .copyPassword
                secondary = wifi.password == nil ? nil : .copyNetworkName
            }
            return ResultSummary(title: wifi.ssid, titleIsMonospaced: true,
                                 kindLabel: wifi.hidden ? "Hidden Wi-Fi network" : "Wi-Fi network",
                                 primary: primary, secondary: secondary, pillIcon: .wifi, safety: nil,
                                 shareText: wifi.ssid)
        case .contact(let contact):
            return ResultSummary(title: contact.displayName, titleIsMonospaced: false, kindLabel: "Contact",
                                 primary: .saveContact, secondary: .copyContact, pillIcon: .person, safety: nil,
                                 shareText: contactText(contact))
        case .phone(let number):
            return ResultSummary(title: number, titleIsMonospaced: true, kindLabel: "Phone number",
                                 primary: .call, secondary: .copyNumber, pillIcon: .phone, safety: nil, shareText: number)
        case .sms(let number, let body):
            return ResultSummary(title: number.isEmpty ? "Text message" : number, titleIsMonospaced: !number.isEmpty,
                                 kindLabel: "Text message", primary: .sendMessage,
                                 secondary: body.isEmpty ? .copyNumber : .copyMessage, pillIcon: .message, safety: nil,
                                 shareText: body.isEmpty ? number : body)
        case .email(let address, _, _):
            return ResultSummary(title: address.isEmpty ? "Email" : address, titleIsMonospaced: !address.isEmpty,
                                 kindLabel: "Email", primary: .email, secondary: .copyEmailAddress,
                                 pillIcon: .envelope, safety: nil, shareText: address)
        case .location(let location):
            return ResultSummary(title: location.query ?? location.coordinates, titleIsMonospaced: location.query == nil,
                                 kindLabel: "Location", primary: .openMaps, secondary: .copyCoordinates,
                                 pillIcon: .pin, safety: nil, shareText: location.coordinates)
        case .text(let text):
            let isBarcode = symbology.map { $0 != "QR" } ?? false
            let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
            return ResultSummary(title: isBarcode ? text : firstLine, titleIsMonospaced: isBarcode,
                                 kindLabel: isBarcode ? "Barcode · \(symbology ?? "")" : "Text",
                                 primary: .copyText, secondary: nil, pillIcon: .text, safety: nil, shareText: text)
        }
    }

    /// Plain-text version of a contact, for Copy details.
    static func contactText(_ contact: Contact) -> String {
        var lines = [contact.displayName]
        if !contact.jobTitle.isEmpty || !contact.organization.isEmpty {
            lines.append([contact.jobTitle, contact.organization].filter { !$0.isEmpty }.joined(separator: ", "))
        }
        lines += contact.phones + contact.emails + contact.urls
        if !contact.address.isEmpty { lines.append(contact.address) }
        return lines.joined(separator: "\n")
    }

    /// The text in the pill: a link's site, a network's name, a person's name.
    /// Long text is cut to fit; the full thing is in the sheet.
    static func pillText(_ summary: ResultSummary, limit: Int = 26) -> String {
        let text = summary.title
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }
}

/// The system links each action opens: Phone, Messages, Mail, Maps, Safari.
nonisolated enum ResultLinks {
    static func web(_ link: String) -> URL? {
        URL(string: link) ?? URL(string: link, encodingInvalidCharacters: true)
    }

    /// Spaces and dashes are for reading; the dialler wants digits and "+".
    static func call(_ number: String) -> URL? {
        URL(string: "tel:" + dialable(number))
    }

    static func message(to number: String, body: String) -> URL? {
        var text = "sms:" + dialable(number)
        if !body.isEmpty { text += "&body=" + encode(body) }
        return URL(string: text)
    }

    static func email(to address: String, subject: String, body: String) -> URL? {
        var query: [String] = []
        if !subject.isEmpty { query.append("subject=" + encode(subject)) }
        if !body.isEmpty { query.append("body=" + encode(body)) }
        return URL(string: "mailto:" + address + (query.isEmpty ? "" : "?" + query.joined(separator: "&")))
    }

    static func maps(_ location: Location) -> URL? {
        let coordinates = String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), location.latitude, location.longitude)
        let label = encode(location.query ?? location.coordinates)
        return URL(string: "maps://?ll=\(coordinates)&q=\(label)")
    }

    static func dialable(_ number: String) -> String {
        number.filter { $0.isNumber || $0 == "+" || $0 == "*" || $0 == "#" }
    }

    private static func encode(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+?#")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }
}
