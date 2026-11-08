//
//  ResultDetails.swift
//  Lensir
//
//  What the expanded drawer lists under "Details": every field the code
//  carried, and for links, each check as its own pass or fail row.
//

import Foundation

nonisolated struct DetailField: Equatable, Sendable {
    var label: String
    var value: String
    var monospaced = false
}

nonisolated struct CheckItem: Equatable, Sendable {
    var title: String
    var passed: Bool
}

nonisolated enum ResultDetails {
    /// Every parsed field, in the order you'd read them off the code.
    static func fields(for payload: Payload) -> [DetailField] {
        switch payload {
        case .link:
            return []
        case .wifi(let wifi):
            return [
                DetailField(label: "Network", value: wifi.ssid, monospaced: true),
                DetailField(label: "Password", value: wifi.password ?? "None needed", monospaced: wifi.password != nil),
                DetailField(label: "Security", value: wifi.security.label),
                DetailField(label: "Hidden network", value: wifi.hidden ? "Yes" : "No"),
            ]
        case .contact(let contact):
            var fields = [DetailField(label: "Name", value: contact.displayName)]
            if !contact.jobTitle.isEmpty { fields.append(DetailField(label: "Job title", value: contact.jobTitle)) }
            if !contact.organization.isEmpty { fields.append(DetailField(label: "Company", value: contact.organization)) }
            fields += contact.phones.map { DetailField(label: "Phone", value: $0, monospaced: true) }
            fields += contact.emails.map { DetailField(label: "Email", value: $0, monospaced: true) }
            fields += contact.urls.map { DetailField(label: "Website", value: $0, monospaced: true) }
            if !contact.address.isEmpty { fields.append(DetailField(label: "Address", value: contact.address)) }
            if !contact.note.isEmpty { fields.append(DetailField(label: "Note", value: contact.note)) }
            return fields
        case .phone(let number):
            return [DetailField(label: "Number", value: number, monospaced: true)]
        case .sms(let number, let body):
            var fields = [DetailField(label: "To", value: number.isEmpty ? "Not given" : number, monospaced: !number.isEmpty)]
            if !body.isEmpty { fields.append(DetailField(label: "Message", value: body)) }
            return fields
        case .email(let address, let subject, let body):
            var fields = [DetailField(label: "To", value: address.isEmpty ? "Not given" : address, monospaced: !address.isEmpty)]
            if !subject.isEmpty { fields.append(DetailField(label: "Subject", value: subject)) }
            if !body.isEmpty { fields.append(DetailField(label: "Message", value: body)) }
            return fields
        case .location(let location):
            let posix = Locale(identifier: "en_US_POSIX")
            var fields = [
                DetailField(label: "Latitude", value: String(format: "%.6f", locale: posix, location.latitude), monospaced: true),
                DetailField(label: "Longitude", value: String(format: "%.6f", locale: posix, location.longitude), monospaced: true),
            ]
            if let query = location.query { fields.append(DetailField(label: "Label", value: query)) }
            return fields
        case .text(let text):
            return [DetailField(label: "Length", value: text.count == 1 ? "1 character" : "\(text.count) characters")]
        }
    }

    /// One row per check, passed or not. Scripts and data pages get a single
    /// failing row: nothing else about them matters.
    static func checks(for report: SafetyReport) -> [CheckItem] {
        let kinds = Set(report.findings.map(\.kind))
        guard let address = report.address, !kinds.contains(.script) else {
            return [CheckItem(title: "A web address, not a script or a packed page", passed: false)]
        }
        let isIP = kinds.contains(.ipAddress)
        return [
            CheckItem(title: "A web address (\(address.scheme):)", passed: true),
            CheckItem(title: "Secure connection (https)", passed: address.scheme == "https"),
            CheckItem(title: "A named site, not a bare IP address", passed: !isIP),
            CheckItem(title: "The real site, not a lookalike", passed: !isIP && !kinds.contains(.lookalike)),
            CheckItem(title: "Plain letters, no punycode or mixed alphabets",
                      passed: !kinds.contains(.mixedScript) && !kinds.contains(.otherAlphabet) && !address.host.contains("xn--")),
            CheckItem(title: "No “@” hiding the real site", passed: !kinds.contains(.userInfo)),
            CheckItem(title: "Not a link shortener", passed: !kinds.contains(.shortener)),
            CheckItem(title: "A normal number of subdomains", passed: !kinds.contains(.manySubdomains)),
            CheckItem(title: "A name that doesn't look made up", passed: !kinds.contains(.randomName)),
        ]
    }
}
