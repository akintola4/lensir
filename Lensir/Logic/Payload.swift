//
//  Payload.swift
//  Lensir
//
//  What a code says, once it's been read. PayloadParser turns the raw text into
//  one of these; the result sheet picks its title and buttons from it.
//

import Foundation

nonisolated enum Payload: Equatable, Sendable {
    case link(String)
    case wifi(WiFi)
    case contact(Contact)
    case phone(String)
    case sms(number: String, body: String)
    case email(address: String, subject: String, body: String)
    case location(Location)
    case text(String)
}

nonisolated struct WiFi: Equatable, Sendable {
    enum Security: String, Equatable, Sendable {
        case open, wep, wpa, wpa3

        var label: String {
            switch self {
            case .open: "None"
            case .wep: "WEP"
            case .wpa: "WPA/WPA2"
            case .wpa3: "WPA3"
            }
        }
    }

    var ssid: String
    var password: String?
    var security: Security
    var hidden: Bool
}

nonisolated struct Contact: Equatable, Sendable {
    var givenName = ""
    var familyName = ""
    /// The whole name as the code wrote it (vCard `FN`), used when the parts are missing.
    var formattedName = ""
    var organization = ""
    var jobTitle = ""
    var phones: [String] = []
    var emails: [String] = []
    var urls: [String] = []
    var address = ""
    var note = ""

    var displayName: String {
        let parts = [givenName, familyName].filter { !$0.isEmpty }
        if !parts.isEmpty { return parts.joined(separator: " ") }
        if !formattedName.isEmpty { return formattedName }
        if !organization.isEmpty { return organization }
        return phones.first ?? emails.first ?? "Contact"
    }
}

nonisolated struct Location: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var query: String?

    /// "6.4541, 3.3947": four decimals is about 11 m, plenty for a meeting point.
    var coordinates: String {
        String(format: "%.4f, %.4f", locale: Locale(identifier: "en_US_POSIX"), latitude, longitude)
    }
}
