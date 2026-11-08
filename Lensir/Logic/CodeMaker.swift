//
//  CodeMaker.swift
//  Lensir
//
//  Turns what you type in the Make drawer into the text a QR code carries,
//  in the forms PayloadParser reads: `WIFI:` for networks, a web address,
//  `tel:` for a number, `MECARD:` for a contact, or the text itself. Pure,
//  so every kind is tested by making it and parsing it back.
//

import Foundation

nonisolated enum CodeKind: String, CaseIterable, Equatable, Sendable {
    /// In the order the approved design draws the chips.
    case wifi, link, phone, contact, text

    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .link: "Link"
        case .phone: "Phone"
        case .contact: "Contact"
        case .text: "Text"
        }
    }

    /// The kind a scanned or kept payload belongs to.
    init(_ payload: Payload) {
        switch payload {
        case .wifi: self = .wifi
        case .link: self = .link
        case .phone: self = .phone
        case .contact: self = .contact
        case .sms, .email, .location, .text: self = .text
        }
    }
}

/// Everything typed into the Make drawer. Each kind keeps its own fields,
/// so switching chips and back loses nothing.
nonisolated struct CodeDraft: Equatable, Sendable {
    var kind: CodeKind = .wifi
    var link = ""
    var ssid = ""
    var password = ""
    var security: WiFi.Security = .wpa
    var phone = ""
    var contactName = ""
    var contactPhone = ""
    var contactEmail = ""
    var text = ""
}

/// Why there's no code yet, said under the form.
nonisolated enum CodeProblem: Error, Equatable, Sendable {
    case empty
    case linkHasSpaces
    case linkIncomplete
    case passwordTooShort(minimum: Int)
    case tooLong

    var message: String? {
        switch self {
        case .empty: nil
        case .linkHasSpaces: "A web address can't have spaces in it."
        case .linkIncomplete: "Add the whole address, like kolalogistics.test."
        case .passwordTooShort(let minimum): "A WPA password is at least \(minimum) characters."
        case .tooLong: "That's too much for one code. Try something shorter."
        }
    }
}

nonisolated enum CodeMaker {
    /// The most a version 40 code holds at correction level M, in bytes.
    static let capacity = 2331
    static let minimumWPAPassword = 8

    /// The text to put in the code, or why there isn't one yet.
    static func make(_ draft: CodeDraft) -> Result<String, CodeProblem> {
        let made: Result<String, CodeProblem> = switch draft.kind {
        case .wifi: wifi(ssid: draft.ssid, password: draft.password, security: draft.security)
        case .link: link(draft.link)
        case .phone: phone(draft.phone)
        case .contact: contact(name: draft.contactName, phone: draft.contactPhone, email: draft.contactEmail)
        case .text: text(draft.text)
        }
        if case .success(let payload) = made, payload.utf8.count > capacity { return .failure(.tooLong) }
        return made
    }

    static func payload(for draft: CodeDraft) -> String? {
        try? make(draft).get()
    }

    // MARK: - Wi-Fi

    /// `WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;`. An open network gets
    /// `T:nopass` and no password.
    static func wifi(ssid: String, password: String, security: WiFi.Security) -> Result<String, CodeProblem> {
        guard !ssid.trimmingCharacters(in: .whitespaces).isEmpty else { return .failure(.empty) }
        let type = switch security {
        case .open: "nopass"
        case .wep: "WEP"
        case .wpa: "WPA"
        case .wpa3: "SAE"
        }
        var payload = "WIFI:T:\(type);S:\(escape(ssid));"
        switch security {
        case .open:
            break
        case .wep:
            guard !password.isEmpty else { return .failure(.empty) }
            payload += "P:\(escape(password));"
        case .wpa, .wpa3:
            guard password.count >= minimumWPAPassword else {
                return .failure(password.isEmpty ? .empty : .passwordTooShort(minimum: minimumWPAPassword))
            }
            payload += "P:\(escape(password));"
        }
        return .success(payload + ";")
    }

    /// `\ ; , : "` each get a backslash, as the Wi-Fi and MECARD formats ask.
    static func escape(_ value: String) -> String {
        var escaped = ""
        for character in value {
            if "\\;,:\"".contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }

    // MARK: - Links

    /// What you'd type in a browser: `kolalogistics.test/track` becomes
    /// `https://kolalogistics.test/track`. Any scheme you typed is kept, so
    /// the safety checks see exactly what the code will carry.
    static func link(_ input: String) -> Result<String, CodeProblem> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }
        guard !text.contains(where: \.isWhitespace) else { return .failure(.linkHasSpaces) }
        let lower = text.lowercased()
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") { return .success(text) }
        let full = lower.hasPrefix("http://") || lower.hasPrefix("https://") ? text : "https://" + text
        // A site needs a name with a dot in it: "kola" alone isn't anywhere yet.
        guard let address = LinkAddress(full), address.hasAuthority,
              address.host.contains("."), !address.host.hasSuffix("."), !address.host.hasPrefix(".")
        else { return .failure(.linkIncomplete) }
        return .success(full)
    }

    /// The safety report for a made link, the same one a scanned link gets.
    static func safety(for draft: CodeDraft) -> SafetyReport? {
        guard draft.kind == .link, let payload = payload(for: draft) else { return nil }
        return LinkSafety.check(payload)
    }

    // MARK: - Phone, contact, text

    /// `tel:+2348060000000`. Spaces and dashes are for reading; the dialler
    /// wants digits and "+".
    static func phone(_ input: String) -> Result<String, CodeProblem> {
        let number = ResultLinks.dialable(input)
        guard number.filter(\.isNumber).count >= 3 else { return .failure(.empty) }
        return .success("tel:" + number)
    }

    /// `MECARD:N:Kola Logistics;TEL:+2348060000000;EMAIL:hello@kolalogistics.test;;`.
    /// Only the fields you filled in.
    static func contact(name: String, phone: String, email: String) -> Result<String, CodeProblem> {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = ResultLinks.dialable(phone)
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !number.isEmpty || !email.isEmpty else { return .failure(.empty) }
        var payload = "MECARD:"
        if !name.isEmpty { payload += "N:\(escape(name));" }
        if !number.isEmpty { payload += "TEL:\(number);" }
        if !email.isEmpty { payload += "EMAIL:\(escape(email));" }
        return .success(payload + ";")
    }

    static func text(_ input: String) -> Result<String, CodeProblem> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? .failure(.empty) : .success(text)
    }

    // MARK: - Names

    /// What a kept code is called until you rename it: the network, the
    /// site, the number as you typed it, the person, or the first line.
    static func defaultName(for draft: CodeDraft) -> String {
        switch draft.kind {
        case .wifi:
            return draft.ssid
        case .link:
            guard let payload = payload(for: draft), let address = LinkAddress(payload), address.hasAuthority else {
                return draft.link.trimmingCharacters(in: .whitespaces)
            }
            return address.shortHost
        case .phone:
            return draft.phone.trimmingCharacters(in: .whitespaces)
        case .contact:
            let options = [draft.contactName, draft.contactPhone, draft.contactEmail].map { $0.trimmingCharacters(in: .whitespaces) }
            return options.first { !$0.isEmpty } ?? "Contact"
        case .text:
            let first = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            return first.count > 40 ? String(first.prefix(39)) + "…" : first
        }
    }
}

// MARK: - Showing a made code

/// What the full-screen code and the My codes rows say about a payload.
nonisolated struct CodeDisplay: Equatable, Sendable {
    var kind: CodeKind
    /// "Wi-Fi · WPA/WPA2" under the name.
    var detail: String
    /// The line over the full-screen code, for whoever is scanning it.
    var caption: String
    /// The name is a network, an address or a number: set it in SF Mono.
    var monospaced: Bool
    /// VoiceOver's description of the code.
    var spokenSummary: String

    var accessibilityLabel: String { "QR code for \(spokenSummary)" }
}

nonisolated extension CodeMaker {
    static func display(raw: String) -> CodeDisplay {
        let payload = PayloadParser.parse(raw)
        switch payload {
        case .wifi(let wifi):
            return CodeDisplay(kind: .wifi,
                               detail: "Wi-Fi · " + (wifi.security == .open ? "no password" : wifi.security.label),
                               caption: "Point your camera here to join",
                               monospaced: true, spokenSummary: "Wi-Fi network \(wifi.ssid)")
        case .link(let link):
            let site = LinkAddress(link).map { $0.hasAuthority ? $0.shortHost : link } ?? link
            return CodeDisplay(kind: .link, detail: link, caption: "Point your camera here to open the link",
                               monospaced: true, spokenSummary: "link to \(site)")
        case .phone(let number):
            return CodeDisplay(kind: .phone, detail: "Phone", caption: "Point your camera here to call",
                               monospaced: true, spokenSummary: "phone number \(number)")
        case .contact(let contact):
            return CodeDisplay(kind: .contact, detail: "Contact", caption: "Point your camera here to save the contact",
                               monospaced: false, spokenSummary: "contact \(contact.displayName)")
        case .sms, .email, .location, .text:
            let summary = ResultLogic.summary(for: payload, raw: raw, canJoinWiFi: false)
            return CodeDisplay(kind: .text, detail: "Text", caption: "Point your camera here to read it",
                               monospaced: false, spokenSummary: "text: \(summary.title)")
        }
    }
}
