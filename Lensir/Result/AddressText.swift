//
//  AddressText.swift
//  Lensir
//
//  The full address, the way Safari's address bar shows it: the site bright
//  and bold, the scheme and path dim. Lookalike letters are red and
//  underlined. Breaks fall after slashes, never inside the site's name.
//

import SwiftUI

enum AddressText {
    static func full(_ raw: String, report: SafetyReport) -> AttributedString {
        guard let address = report.address, address.hasAuthority else {
            var text = AttributedString(breakable(raw))
            text.foregroundColor = Palette.secondaryText
            text.font = Typeface.address
            return text
        }
        var text = dim(address.scheme + "://")
        if let userInfo = address.userInfo {
            text += dim(breakable(userInfo) + "@")
        }
        text += host(address.displayHost, highlights: report.highlights, font: Typeface.addressBold)
        if let port = address.port {
            text += dim(":" + port)
        }
        text += dim(breakable(address.rest))
        return text
    }

    /// The site's name for a title, with the same red underlines. It wraps
    /// after a dot rather than mid-word or hyphenated, which would look like
    /// part of the address: "paystack." then "com", never "pay-" "stack".
    static func title(_ report: SafetyReport, breaksAtDots: Bool = true) -> AttributedString? {
        guard let address = report.address, address.hasAuthority else { return nil }
        let offset = address.shortHostOffset
        let ranges = report.highlights.compactMap { range -> Range<Int>? in
            let shifted = (range.lowerBound - offset)..<(range.upperBound - offset)
            return shifted.lowerBound >= 0 ? shifted : nil
        }
        return host(address.shortHost, highlights: ranges, font: nil, breaksAtDots: breaksAtDots)
    }

    private static func host(_ text: String, highlights: [Range<Int>], font: Font?, breaksAtDots: Bool = false) -> AttributedString {
        var result = AttributedString()
        for (index, character) in text.enumerated() {
            var piece = AttributedString(String(character))
            if let font { piece.font = font }
            if highlights.contains(where: { $0.contains(index) }) {
                piece.foregroundColor = Palette.warning
                piece.underlineStyle = Text.LineStyle(pattern: .solid, color: Palette.warning)
            } else {
                piece.foregroundColor = Palette.ink
            }
            result += piece
            if breaksAtDots && character == "." { result += AttributedString("\u{200B}") }
        }
        return result
    }

    private static func dim(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = Palette.secondaryText
        result.font = Typeface.address
        return result
    }

    /// Typesetting with no language: a part too long for its line breaks
    /// where it must, without a hyphen that would read as part of the
    /// address ("kolalogis-tics.test").
    static let noHyphens = Locale.Language(identifier: "zxx")

    /// A zero-width space after each dot, so a name like a domain wraps
    /// between its parts instead of mid-word.
    static func breakingAtDots(_ text: String) -> String {
        var result = ""
        for character in text {
            result.append(character)
            if character == "." { result.append("\u{200B}") }
        }
        return result
    }

    /// A zero-width space after each separator, so long paths wrap at "/"
    /// and "?" instead of mid-word.
    static func breakable(_ text: String) -> String {
        var result = ""
        for character in text {
            result.append(character)
            if "/?&=#".contains(character) { result.append("\u{200B}") }
        }
        return result
    }
}
