//
//  Confusables.swift
//  Lensir
//
//  Letters that look like other letters. The skeleton of a name swaps every
//  lookalike for the plain Latin letter it imitates, so "pаypа1" (Cyrillic а,
//  digit 1) and "paypal" come out the same and the check can tell.
//
//  The table is a hand-picked subset of Unicode's confusables.txt: the
//  letters that actually turn up in phishing domains, not all 6,000 entries.
//

import Foundation

nonisolated enum Script: String, Sendable {
    case latin = "Latin"
    case cyrillic = "Cyrillic"
    case greek = "Greek"
    case armenian = "Armenian"
    case cherokee = "Cherokee"
    case fullwidth = "full-width"
    case other = "non-English"
    /// Digits, hyphens and anything else every script shares.
    case common

    static func of(_ character: Character) -> Script {
        guard let scalar = character.unicodeScalars.first else { return .common }
        switch scalar.value {
        case 0x30...0x39, 0x2D, 0x5F: return .common
        case 0x41...0x5A, 0x61...0x7A: return .latin
        case 0x00C0...0x024F, 0x1E00...0x1EFF, 0x0250...0x02AF: return .latin
        case 0x0370...0x03FF, 0x1F00...0x1FFF: return .greek
        case 0x0400...0x052F, 0x1C80...0x1C8F, 0xA640...0xA69F: return .cyrillic
        case 0x0530...0x058F: return .armenian
        case 0x13A0...0x13FF, 0xAB70...0xABBF: return .cherokee
        case 0xFF00...0xFFEF: return .fullwidth
        default: return scalar.isASCII ? .common : .other
        }
    }

    /// "a Cyrillic letter", "an Armenian letter".
    var letterPhrase: String {
        switch self {
        case .armenian: "an Armenian letter"
        case .other: "a letter from another alphabet"
        case .fullwidth: "a full-width letter"
        default: "a \(rawValue) letter"
        }
    }
}

nonisolated enum Confusables {
    /// Lookalike → the Latin letter it imitates.
    static let toLatin: [Character: String] = [
        // Cyrillic
        "а": "a", "е": "e", "ё": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x",
        "ѕ": "s", "і": "i", "ї": "i", "ј": "j", "ԁ": "d", "ԛ": "q", "ԝ": "w", "һ": "h",
        "ӏ": "l", "к": "k", "п": "n", "г": "r", "ь": "b", "ɡ": "g", "ҽ": "e", "ө": "o",
        // Greek
        "α": "a", "ο": "o", "ν": "v", "ι": "i", "κ": "k", "ρ": "p", "τ": "t", "υ": "u",
        "χ": "x", "ε": "e", "ϲ": "c", "ϳ": "j", "ω": "w", "η": "n", "μ": "u", "β": "b",
        // Armenian
        "օ": "o", "ս": "u", "հ": "h", "ո": "n", "ց": "g", "զ": "q", "ա": "w",
        // Latin letters that pass for other Latin letters
        "ı": "i", "ɑ": "a", "ł": "l", "ŀ": "l", "ƚ": "l", "ɩ": "i", "ʟ": "l", "ꞁ": "l",
        "à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ā": "a",
        "è": "e", "é": "e", "ê": "e", "ë": "e", "ē": "e",
        "ì": "i", "í": "i", "î": "i", "ï": "i", "ò": "o", "ó": "o", "ô": "o", "õ": "o",
        "ö": "o", "ø": "o", "ù": "u", "ú": "u", "û": "u", "ü": "u", "ñ": "n", "ç": "c",
        "ý": "y", "ÿ": "y", "ś": "s", "š": "s", "ž": "z", "ć": "c", "č": "c", "ğ": "g",
    ]

    /// The plain-Latin shape of a name, for comparing against known brands.
    /// Lower-cased first; then digits and letter pairs that imitate letters
    /// are folded too (0→o, 1→l, i→l, rn→m, vv→w), on both sides of every
    /// comparison, so "paypa1" and "paypal" meet at "paypal".
    static func skeleton(_ text: String) -> String {
        var result = ""
        for character in text.lowercased() {
            if let latin = toLatin[character] {
                result += latin
            } else if let scalar = character.unicodeScalars.first, (0xFF41...0xFF5A).contains(scalar.value),
                      let ascii = UnicodeScalar(scalar.value - 0xFEE0) {
                result.unicodeScalars.append(ascii)
            } else {
                result.append(character)
            }
        }
        result = result
            .replacingOccurrences(of: "rn", with: "m")
            .replacingOccurrences(of: "vv", with: "w")
        return String(result.map { character -> Character in
            switch character {
            case "0": "o"
            case "1", "i", "|": "l"
            default: character
            }
        })
    }

    /// How a single swapped character is described: "the number one, not an “l”".
    static func describeSwap(_ fake: String, for real: String) -> String {
        if fake.count == 1, let character = fake.first {
            let script = Script.of(character)
            if script != .latin && script != .common {
                return "is \(script.letterPhrase)"
            }
            switch (fake, real) {
            case ("0", "o"): return "is the number zero, not an “o”"
            case ("1", "l"): return "is the number one, not an “l”"
            case ("1", "i"): return "is the number one, not an “i”"
            default: break
            }
            if !character.isASCII { return "is an accented letter, not “\(real)”" }
        }
        if fake.count > 1, fake.allSatisfy({ $0 == "0" }) {
            return "is \(fake.count == 2 ? "two" : String(fake.count)) zeros, not “\(real)”"
        }
        if fake == "rn" && real == "m" { return "is “r” and “n” side by side, not an “m”" }
        if fake == "vv" && real == "w" { return "is two “v”s, not a “w”" }
        if real.isEmpty { return "is an extra letter" }
        return "should be “\(real)”"
    }
}
