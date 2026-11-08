//
//  ResultDetails.swift
//  Lensir
//
//  The rows the drawer lists: a few under the title in compact, and under
//  "Details" only what compact doesn't already show, plus, for links, each
//  check as its own pass or fail row.
//

import Foundation

nonisolated struct DetailField: Equatable, Sendable {
    var label: String
    var value: String
    var monospaced = false
}

nonisolated struct CheckItem: Equatable, Sendable {
    /// The whole check, for VoiceOver: "Secure connection (https)".
    var title: String
    var passed: Bool
    /// A word or two for its chip, naming what a pass means: "https".
    var label: String
}

nonisolated enum ResultDetails {
    /// The rows under the title in the compact drawer. The title itself (a
    /// network's name, a person's, a number) is never repeated here.
    static func compactFields(for payload: Payload) -> [DetailField] {
        switch payload {
        case .link, .phone, .text:
            return []
        case .wifi(let wifi):
            return [
                DetailField(label: "Password", value: wifi.password ?? "None needed", monospaced: wifi.password != nil),
                DetailField(label: "Security", value: wifi.security.label),
            ]
        case .contact(let contact):
            var fields = contact.phones.prefix(2).map { DetailField(label: "Phone", value: $0, monospaced: true) }
            fields += contact.emails.prefix(2).map { DetailField(label: "Email", value: $0, monospaced: true) }
            if let work = work(contact), work != contact.displayName { fields.append(DetailField(label: "Work", value: work)) }
            if !contact.address.isEmpty { fields.append(DetailField(label: "Address", value: contact.address)) }
            return fields
        case .sms(_, let body):
            return body.isEmpty ? [] : [DetailField(label: "Message", value: body)]
        case .email(_, let subject, let body):
            var fields: [DetailField] = []
            if !subject.isEmpty { fields.append(DetailField(label: "Subject", value: subject)) }
            if !body.isEmpty { fields.append(DetailField(label: "Message", value: body)) }
            return fields
        case .location(let location):
            return location.query == nil ? [] : [DetailField(label: "Coordinates", value: location.coordinates, monospaced: true)]
        }
    }

    /// What Details adds under the compact drawer: only what the title and
    /// the compact rows don't already say.
    static func moreFields(for payload: Payload) -> [DetailField] {
        switch payload {
        case .link, .wifi, .phone, .location:
            // A hidden network says so in its label; coordinates and labels
            // are the title or a compact row already.
            return []
        case .contact(let contact):
            var fields = contact.phones.dropFirst(2).map { DetailField(label: "Phone", value: $0, monospaced: true) }
            fields += contact.emails.dropFirst(2).map { DetailField(label: "Email", value: $0, monospaced: true) }
            fields += contact.urls.map { DetailField(label: "Website", value: $0, monospaced: true) }
            if !contact.note.isEmpty { fields.append(DetailField(label: "Note", value: contact.note)) }
            return fields
        case .sms(let number, _):
            return number.isEmpty ? [DetailField(label: "To", value: "Not given")] : []
        case .email(let address, _, _):
            return address.isEmpty ? [DetailField(label: "To", value: "Not given")] : []
        case .text(let text):
            return [DetailField(label: "Length", value: text.count == 1 ? "1 character" : "\(text.count) characters")]
        }
    }

    /// A job title and a company on one line.
    private static func work(_ contact: Contact) -> String? {
        let work = [contact.jobTitle, contact.organization].filter { !$0.isEmpty }.joined(separator: ", ")
        return work.isEmpty ? nil : work
    }

    /// One per check, passed or not, in a fixed order. Scripts and data
    /// pages get a single failing check: nothing else about them matters.
    static func checks(for report: SafetyReport) -> [CheckItem] {
        let kinds = Set(report.findings.map(\.kind))
        guard let address = report.address, !kinds.contains(.script) else {
            return [CheckItem(title: "A web address, not a script or a packed page", passed: false, label: "Web address")]
        }
        let isIP = kinds.contains(.ipAddress)
        return [
            CheckItem(title: "A web address (\(address.scheme):)", passed: true, label: "Web address"),
            CheckItem(title: "Secure connection (https)", passed: address.scheme == "https", label: "https"),
            CheckItem(title: "A named site, not a bare IP address", passed: !isIP, label: "Named site"),
            CheckItem(title: "The real site, not a lookalike", passed: !isIP && !kinds.contains(.lookalike), label: "Real site"),
            CheckItem(title: "Plain letters, no punycode or mixed alphabets",
                      passed: !kinds.contains(.mixedScript) && !kinds.contains(.otherAlphabet) && !address.host.contains("xn--"),
                      label: "Plain letters"),
            CheckItem(title: "No “@” hiding the real site", passed: !kinds.contains(.userInfo), label: "No @ trick"),
            CheckItem(title: "Not a link shortener", passed: !kinds.contains(.shortener), label: "Not shortened"),
            CheckItem(title: "A normal number of subdomains", passed: !kinds.contains(.manySubdomains), label: "Few subdomains"),
            CheckItem(title: "A name that doesn't look made up", passed: !kinds.contains(.randomName), label: "Real-looking name"),
        ]
    }
}
