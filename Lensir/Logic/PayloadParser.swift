//
//  PayloadParser.swift
//  Lensir
//
//  Reads the text inside a code and works out what it is: a link, a Wi-Fi
//  network, a contact, a phone number, a text message, an email, a place, or
//  plain text. Pure and synchronous, so it's tested without a camera.
//

import Foundation

nonisolated enum PayloadParser {
    static func parse(_ raw: String) -> Payload {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()

        if lower.hasPrefix("wifi:"), let wifi = wifi(text) { return .wifi(wifi) }
        if lower.hasPrefix("mecard:") { return .contact(mecard(text)) }
        if lower.hasPrefix("begin:vcard") { return .contact(vcard(text)) }
        if lower.hasPrefix("tel:") {
            let number = String(text.dropFirst(4)).removingPercentEncoding ?? String(text.dropFirst(4))
            if !number.isEmpty { return .phone(number) }
        }
        if lower.hasPrefix("smsto:") || lower.hasPrefix("sms:") || lower.hasPrefix("mmsto:") {
            return sms(text)
        }
        if lower.hasPrefix("mailto:") { return mailto(text) }
        if lower.hasPrefix("matmsg:") { return matmsg(text) }
        if lower.hasPrefix("geo:"), let location = geo(text) { return .location(location) }
        if let link = link(text) { return .link(link) }
        return .text(text)
    }

    // MARK: - Links

    /// Web addresses, plus the two schemes that only pretend to be links
    /// (`javascript:` and `data:`) so the safety checks can say so.
    private static func link(_ text: String) -> String? {
        let lower = text.lowercased()
        for prefix in ["urlto:", "url:"] where lower.hasPrefix(prefix) {
            let rest = String(text.dropFirst(prefix.count))
            return link(rest) ?? rest
        }
        guard !text.contains(where: \.isNewline), !text.contains(" ") else { return nil }
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return text }
        if lower.hasPrefix("javascript:") || lower.hasPrefix("data:") { return text }
        // "www.example.com" with no scheme: Safari opens it over http.
        if lower.hasPrefix("www."), lower.dropFirst(4).contains(".") { return "http://" + text }
        return nil
    }

    // MARK: - Wi-Fi

    /// `WIFI:T:WPA;S:Home;P:pa\;ss;H:true;;`. Fields come in any order, and
    /// `\` escapes `\ ; , : "` inside a value.
    static func wifi(_ text: String) -> WiFi? {
        let fields = fields(in: String(text.dropFirst("WIFI:".count)))
        guard let ssid = fields["S"], !ssid.isEmpty else { return nil }
        let password = fields["P"].flatMap { $0.isEmpty ? nil : $0 }
        let type = (fields["T"] ?? "").uppercased()
        let security: WiFi.Security = switch type {
        case "WEP": .wep
        case "SAE", "WPA3": .wpa3
        case "NOPASS", "NONE": .open
        case "": password == nil ? .open : .wpa
        default: .wpa
        }
        let hidden = (fields["H"] ?? "").lowercased() == "true"
        return WiFi(ssid: ssid, password: security == .open ? nil : password, security: security, hidden: hidden)
    }

    // MARK: - Contacts

    /// `MECARD:N:Okafor,Ada;TEL:+234...;EMAIL:ada@example.com;;`
    static func mecard(_ text: String) -> Contact {
        var contact = Contact()
        // An escaped comma ("Kola Logistics\, Ikeja") is part of the name,
        // not the break between family and given name.
        let comma = String(escapedComma)
        for (key, marked) in orderedFields(in: String(text.dropFirst("MECARD:".count)), markingCommas: true) where !marked.isEmpty {
            let value = marked.replacingOccurrences(of: comma, with: ",")
            switch key {
            case "N":
                let parts = marked.split(separator: ",", maxSplits: 1).map {
                    $0.replacingOccurrences(of: comma, with: ",").trimmingCharacters(in: .whitespaces)
                }
                if parts.count == 2 {
                    contact.familyName = parts[0]
                    contact.givenName = parts[1]
                } else {
                    contact.formattedName = value
                }
            case "TEL": contact.phones.append(value)
            case "EMAIL": contact.emails.append(value)
            case "URL": contact.urls.append(value)
            case "ADR": contact.address = value
            case "NOTE": contact.note = value
            case "ORG": contact.organization = value
            default: break
            }
        }
        return contact
    }

    /// vCard 2.1, 3.0 and 4.0. Folded lines are joined first, then each
    /// property is read by name, ignoring its parameters (`TEL;TYPE=CELL:`).
    static func vcard(_ text: String) -> Contact {
        var contact = Contact()
        var lines: [String] = []
        for line in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if let first = line.first, first == " " || first == "\t", !lines.isEmpty {
                lines[lines.count - 1] += line.dropFirst()
            } else {
                lines.append(line)
            }
        }
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].split(separator: ";").first.map { String($0).uppercased() } ?? ""
            // Grouped properties look like "item1.EMAIL".
            let property = name.split(separator: ".").last.map(String.init) ?? name
            let value = unescapeVCard(String(line[line.index(after: colon)...]))
            guard !value.isEmpty else { continue }
            switch property {
            case "FN": contact.formattedName = value
            case "N":
                let parts = value.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
                contact.familyName = parts.first ?? ""
                contact.givenName = parts.count > 1 ? parts[1] : ""
            case "ORG": contact.organization = value.split(separator: ";").first.map(String.init) ?? value
            case "TITLE": contact.jobTitle = value
            case "TEL": contact.phones.append(value.hasPrefix("tel:") ? String(value.dropFirst(4)) : value)
            case "EMAIL": contact.emails.append(value)
            case "URL": contact.urls.append(value)
            case "ADR":
                contact.address = value.split(separator: ";", omittingEmptySubsequences: true)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
            case "NOTE": contact.note = value
            default: break
            }
        }
        return contact
    }

    private static func unescapeVCard(_ value: String) -> String {
        var result = ""
        var escaping = false
        for character in value {
            if escaping {
                result.append(character == "n" || character == "N" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Messages

    /// `SMSTO:+2348012345678:Hello`, `sms:+2348012345678?body=Hello` and
    /// `sms:+2348012345678;?&body=Hello` (iOS's own form).
    private static func sms(_ text: String) -> Payload {
        let lower = text.lowercased()
        if lower.hasPrefix("smsto:") || lower.hasPrefix("mmsto:") {
            let rest = text.dropFirst(6)
            let parts = rest.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            return .sms(number: String(parts.first ?? ""), body: parts.count > 1 ? String(parts[1]) : "")
        }
        let rest = String(text.dropFirst(4))
        let (path, query) = splitQuery(rest)
        var number = path
        var body = query["body"] ?? ""
        // A few generators write "sms:number:message" like SMSTO.
        if body.isEmpty, let colon = number.firstIndex(of: ":") {
            body = String(number[number.index(after: colon)...])
            number = String(number[..<colon])
        }
        number = number.trimmingCharacters(in: CharacterSet(charactersIn: ";,"))
        return .sms(number: number.removingPercentEncoding ?? number, body: body)
    }

    /// `mailto:hello@example.com?subject=Hi&body=...`
    private static func mailto(_ text: String) -> Payload {
        let (path, query) = splitQuery(String(text.dropFirst("mailto:".count)))
        let address = path.removingPercentEncoding ?? path
        return .email(address: address.isEmpty ? (query["to"] ?? "") : address,
                      subject: query["subject"] ?? "", body: query["body"] ?? "")
    }

    /// `MATMSG:TO:hello@example.com;SUB:Hi;BODY:Text;;`
    private static func matmsg(_ text: String) -> Payload {
        let fields = fields(in: String(text.dropFirst("MATMSG:".count)))
        return .email(address: fields["TO"] ?? "", subject: fields["SUB"] ?? "", body: fields["BODY"] ?? "")
    }

    // MARK: - Places

    /// `geo:6.4541,3.3947`, with an optional altitude and `?q=` label.
    private static func geo(_ text: String) -> Location? {
        let (path, query) = splitQuery(String(text.dropFirst(4)))
        let numbers = path.split(separator: ";").first?.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } ?? []
        guard numbers.count >= 2, (-90...90).contains(numbers[0]), (-180...180).contains(numbers[1]) else { return nil }
        var label = query["q"]
        // "geo:0,0?q=6.45,3.39(Office)" puts the place in the query.
        if let q = label, numbers[0] == 0, numbers[1] == 0 {
            let coordinates = q.split(separator: "(").first?.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } ?? []
            if coordinates.count == 2 {
                let name = q.split(separator: "(", maxSplits: 1).dropFirst().first.map { String($0.dropLast(q.hasSuffix(")") ? 1 : 0)) }
                return Location(latitude: coordinates[0], longitude: coordinates[1], query: name)
            }
            label = q
        }
        return Location(latitude: numbers[0], longitude: numbers[1], query: label?.isEmpty == true ? nil : label)
    }

    // MARK: - Helpers

    /// Splits `KEY:value;KEY:value;;` on unescaped semicolons and unescapes
    /// each value. Keys are upper-cased. The first value for a key wins.
    private static func fields(in body: String) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in orderedFields(in: body) where result[key] == nil {
            result[key] = value
        }
        return result
    }

    private static let escapedComma: Character = "\u{F8FE}"

    /// `markingCommas` leaves escaped commas as `escapedComma`, for fields
    /// whose own commas mean something (MECARD's `N:Family,Given`).
    private static func orderedFields(in body: String, markingCommas: Bool = false) -> [(String, String)] {
        var pairs: [(String, String)] = []
        var current = ""
        var escaping = false
        func flush() {
            defer { current = "" }
            guard let colon = current.firstIndex(of: ":") else { return }
            let key = current[..<colon].uppercased()
            pairs.append((key, String(current[current.index(after: colon)...])))
        }
        // Escapes are resolved as we go, but the key/value colon is the first
        // *unescaped* one, so mark escaped colons and swap them back after.
        let escapedColon: Character = "\u{F8FF}"
        for character in body {
            if escaping {
                current.append(character == ":" ? escapedColon : (markingCommas && character == "," ? escapedComma : character))
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if character == ";" {
                flush()
            } else {
                current.append(character)
            }
        }
        flush()
        return pairs.map { ($0.0.replacingOccurrences(of: String(escapedColon), with: ":"),
                            $0.1.replacingOccurrences(of: String(escapedColon), with: ":")) }
    }

    private static func splitQuery(_ text: String) -> (String, [String: String]) {
        guard let mark = text.firstIndex(of: "?") else { return (text, [:]) }
        var query: [String: String] = [:]
        for pair in text[text.index(after: mark)...].split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let key = parts.first, !key.isEmpty else { continue }
            // "+" stays a plus: mailto and sms bodies carry phone numbers, and
            // RFC 6068 spells a space as %20.
            let raw = parts.count > 1 ? String(parts[1]) : ""
            query[key.lowercased()] = raw.removingPercentEncoding ?? raw
        }
        return (String(text[..<mark]), query)
    }
}
