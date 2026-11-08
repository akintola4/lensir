//
//  LinkSafety.swift
//  Lensir
//
//  Checks a link on the phone, with no network: is it https, is it a short
//  link hiding where it goes, a bare IP, a script, an "@" trick, too many
//  subdomains, a random-looking name, letters from another alphabet, or a
//  name made to look like a site people trust. Each problem comes back as
//  one plain-English line, with the exact letters to underline.
//

import Foundation

nonisolated struct SafetyFinding: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case notHTTPS, shortener, ipAddress, script, userInfo
        case manySubdomains, randomName, otherAlphabet, mixedScript, lookalike
    }

    var kind: Kind
    var message: String
    /// Character offsets into `LinkAddress.displayHost` to underline in red.
    var highlights: [Range<Int>] = []
}

nonisolated struct SafetyReport: Equatable, Sendable {
    var address: LinkAddress?
    var findings: [SafetyFinding]
    /// The brand this link really belongs to, when it's on one of their domains.
    var owner: Brand?

    var isSafe: Bool { findings.isEmpty }

    /// Scripts and data pages can't be opened in Safari at all.
    var canOpen: Bool { !findings.contains { $0.kind == .script } && address != nil }

    var highlights: [Range<Int>] { findings.flatMap(\.highlights) }

    /// The one line under a clean link.
    var safeSummary: String {
        if let owner { return "Secure · the real \(owner.mainDomain)" }
        return "Secure · nothing odd in the address"
    }
}

nonisolated enum LinkSafety {
    static func check(_ raw: String) -> SafetyReport {
        guard let address = LinkAddress(raw) else {
            return SafetyReport(address: nil, findings: [SafetyFinding(kind: .script, message: "This isn't a web address Lensir can read.")], owner: nil)
        }
        var findings: [SafetyFinding] = []

        switch address.scheme {
        case "javascript":
            return SafetyReport(address: address, findings: [SafetyFinding(kind: .script, message: "This isn't a web address. It's a script that runs as soon as it's opened.")], owner: nil)
        case "data":
            return SafetyReport(address: address, findings: [SafetyFinding(kind: .script, message: "This isn't a web address. It's a whole page packed into the code, a common way to fake a login page.")], owner: nil)
        case "http":
            findings.append(SafetyFinding(kind: .notHTTPS, message: "Not secure: it uses http, so anyone on the same Wi‑Fi can see what you send."))
        default:
            break
        }

        guard address.hasAuthority else {
            findings.append(SafetyFinding(kind: .script, message: "This link has no site in it."))
            return SafetyReport(address: address, findings: findings, owner: nil)
        }

        if let userInfo = address.userInfo, !userInfo.isEmpty {
            findings.append(SafetyFinding(kind: .userInfo, message: "Everything before the “@” is decoration. This link really goes to \(address.registrableDomain)."))
        }

        if isIPAddress(address.displayHost) {
            findings.append(SafetyFinding(kind: .ipAddress, message: "It goes to a bare number (\(address.displayHost)) instead of a named site."))
            return SafetyReport(address: address, findings: findings, owner: nil)
        }

        if Brands.shorteners.contains(address.registrableDomain) {
            findings.append(SafetyFinding(kind: .shortener, message: "\(address.registrableDomain) is a link shortener. It hides where the link really goes, and Lensir can't look without going online."))
        }

        let owner = Brands.owner(of: address.registrableDomain)
        findings += alphabetFindings(address, owner: owner)
        if owner == nil {
            findings += lookalikeFindings(address, existing: findings)
            if let random = randomNameFinding(address) { findings.append(random) }
        }

        let realSubdomains = address.subdomains.filter { $0 != "www" }
        if realSubdomains.count >= 4 {
            findings.append(SafetyFinding(kind: .manySubdomains, message: "It has \(realSubdomains.count) parts in front of the real site, \(address.registrableDomain), which hides it at the end."))
        }

        return SafetyReport(address: address, findings: findings, owner: owner)
    }

    // MARK: - Alphabets

    /// Letters from another alphabet. A label that mixes Latin with Cyrillic
    /// or Greek is almost always a trick; a label wholly in another alphabet
    /// is usually a real local site, but it still gets a line.
    private static func alphabetFindings(_ address: LinkAddress, owner: Brand?) -> [SafetyFinding] {
        let host = Array(address.displayHost)
        guard host.contains(where: { !$0.isASCII }) else { return [] }

        var offset = 0
        var mixed: [(Int, Character, Script)] = []
        var otherScripts: Set<String> = []
        for label in address.displayHost.split(separator: ".", omittingEmptySubsequences: false) {
            let characters = Array(label)
            let scripts = Set(characters.map(Script.of).filter { $0 != .common })
            let foreign = scripts.subtracting([.latin])
            if scripts.contains(.latin) && !foreign.isEmpty {
                for (index, character) in characters.enumerated() where foreign.contains(Script.of(character)) {
                    mixed.append((offset + index, character, Script.of(character)))
                }
            } else if !foreign.isEmpty {
                otherScripts.formUnion(foreign.map(\.rawValue))
            }
            // Accented Latin letters that imitate plain ones (é for e).
            for (index, character) in characters.enumerated() where Script.of(character) == .latin && !character.isASCII {
                mixed.append((offset + index, character, .latin))
            }
            offset += characters.count + 1
        }

        let target = imitatedBrand(address)
        let notTarget = target.map { ", so this is not \($0.mainDomain)" } ?? ""
        var findings: [SafetyFinding] = []
        if let (_, character, script) = mixed.first {
            let what = script == .latin ? "an accented letter" : script.letterPhrase
            let message = mixed.count == 1
                ? "The underlined “\(character)” is \(what)\(notTarget)."
                : "The underlined letters aren't plain English letters\(notTarget)."
            findings.append(SafetyFinding(kind: .mixedScript, message: message,
                                          highlights: mixed.map { $0.0..<($0.0 + 1) }))
        }
        if !otherScripts.isEmpty && owner == nil {
            let names = otherScripts.sorted().joined(separator: " and ")
            findings.append(SafetyFinding(kind: .otherAlphabet, message: "The address is written in \(names) letters. Check it's the site you expect."))
        }
        return findings
    }

    // MARK: - Lookalikes

    private static func lookalikeFindings(_ address: LinkAddress, existing: [SafetyFinding]) -> [SafetyFinding] {
        let label = address.siteLabel
        let alreadyExplained = existing.contains { $0.kind == .mixedScript }

        // 1. The name looks the same as a brand once lookalike letters are folded.
        if let brand = imitatedBrand(address) {
            var findings: [SafetyFinding] = []
            if !alreadyExplained, let name = brand.names.first(where: { Confusables.skeleton($0) == Confusables.skeleton(label) }) {
                let (fake, real, range) = difference(label, name)
                let start = labelOffset(address)
                findings.append(SafetyFinding(
                    kind: .lookalike,
                    message: "The underlined “\(fake)” \(Confusables.describeSwap(fake, for: real)), so this is not \(brand.mainDomain).",
                    highlights: [(start + range.lowerBound)..<(start + range.upperBound)]
                ))
            }
            findings.append(SafetyFinding(kind: .lookalike, message: "Made to look like a site you know."))
            return findings
        }

        // 2. The brand's exact name on a domain it doesn't own. Brands that
        //    trade in many countries get a pass on country endings (amazon.de).
        if let brand = Brands.all.first(where: { $0.names.contains(label) }) {
            let ending = address.registrableDomain.split(separator: ".").dropFirst().joined(separator: ".")
            let countryEnding = ending.split(separator: ".").last?.count == 2 && !Brands.hostingSuffixes.contains(ending)
            if brand.international && countryEnding { return [] }
            return [SafetyFinding(kind: .lookalike, message: "This uses the name “\(label)”, but the real site is \(brand.mainDomain).")]
        }

        // 3. A typo of a brand: one letter off (two for long names).
        if let (brand, name) = typoBrand(label) {
            let (fake, real, range) = difference(label, name)
            let start = labelOffset(address)
            let detail = fake.isEmpty
                ? "It's missing a letter from \(brand.mainDomain), so this is not that site."
                : "The underlined “\(fake)” \(Confusables.describeSwap(fake, for: real)), so this is not \(brand.mainDomain)."
            let highlight = fake.isEmpty ? [] : [(start + range.lowerBound)..<(start + range.upperBound)]
            return [
                SafetyFinding(kind: .lookalike, message: detail, highlights: highlight),
                SafetyFinding(kind: .lookalike, message: "Made to look like a site you know."),
            ]
        }

        // 4. A brand's name borrowed: in a subdomain (paystack.com.evil.io) or
        //    as part of another name (paystack-login.com).
        for brand in Brands.all {
            for name in brand.names {
                if address.subdomains.contains(where: { tokens($0).contains(name) }) {
                    return [SafetyFinding(kind: .lookalike, message: "This is not \(brand.mainDomain). “\(name)” is only at the start; the site is really \(address.registrableDomain).")]
                }
                let parts = tokens(label)
                if (parts.count > 1 && parts.contains(name)) || (name.count >= 8 && label != name && label.contains(name)) {
                    return [SafetyFinding(kind: .lookalike, message: "This is not \(brand.mainDomain). It borrows the name “\(name)” for a different site.")]
                }
            }
        }
        return []
    }

    /// The brand whose name this site's name imitates letter for letter,
    /// using lookalike characters. Exact matches on another ending
    /// (jumia.ug) aren't counted: brands own lots of endings.
    private static func imitatedBrand(_ address: LinkAddress) -> Brand? {
        let label = address.siteLabel
        guard Brands.owner(of: address.registrableDomain) == nil else { return nil }
        let skeleton = Confusables.skeleton(label)
        return Brands.all.first { brand in
            brand.names.contains { $0 != label && Confusables.skeleton($0) == skeleton }
        }
    }

    private static func typoBrand(_ label: String) -> (Brand, String)? {
        guard !Brands.nearMissAllowList.contains(label) else { return nil }
        for brand in Brands.all {
            for name in brand.names where name.count >= 6 && name != label {
                let allowed = name.count >= 10 ? 2 : 1
                if abs(name.count - label.count) <= allowed,
                   editDistance(Confusables.skeleton(label), Confusables.skeleton(name)) <= allowed {
                    return (brand, name)
                }
            }
        }
        return nil
    }

    /// Where the site label starts inside displayHost.
    private static func labelOffset(_ address: LinkAddress) -> Int {
        address.subdomains.reduce(0) { $0 + $1.count + 1 }
    }

    /// The part of `fake` that differs from `real`, found by trimming the
    /// common start and end: ("paypa1", "paypal") → ("1", "l", 5..<6).
    static func difference(_ fake: String, _ real: String) -> (String, String, Range<Int>) {
        let a = Array(fake), b = Array(real)
        var prefix = 0
        while prefix < a.count, prefix < b.count, a[prefix] == b[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < a.count - prefix, suffix < b.count - prefix, a[a.count - 1 - suffix] == b[b.count - 1 - suffix] { suffix += 1 }
        let fakePart = String(a[prefix..<(a.count - suffix)])
        let realPart = String(b[prefix..<(b.count - suffix)])
        return (fakePart, realPart, prefix..<(a.count - suffix))
    }

    /// Damerau–Levenshtein (optimal string alignment): swaps of two
    /// neighbouring letters ("paytsack") count as one edit.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }

    private static func tokens(_ label: String) -> [String] {
        label.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
    }

    // MARK: - Shape of the name

    private static func isIPAddress(_ host: String) -> Bool {
        if host.hasPrefix("[") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.count == 4, parts.allSatisfy({ part in Int(part).map { (0...255).contains($0) } ?? false }) { return true }
        // 3232235521 and 0xC0A80001 both reach 192.168.0.1.
        if parts.count == 1 {
            let text = String(parts[0])
            if text.allSatisfy(\.isNumber) { return true }
            if text.hasPrefix("0x"), text.dropFirst(2).allSatisfy(\.isHexDigit), text.count > 2 { return true }
        }
        return false
    }

    /// A long name that reads like a password: digits mixed through letters,
    /// a long run of consonants, or hardly any vowels.
    private static func randomNameFinding(_ address: LinkAddress) -> SafetyFinding? {
        let candidates = [address.siteLabel] + address.subdomains
        for label in candidates where label.count >= 12 && label.allSatisfy(\.isASCII) {
            if looksRandom(label) {
                return SafetyFinding(kind: .randomName, message: "The name “\(label)” looks randomly made up, which throwaway scam sites often are.")
            }
        }
        return nil
    }

    static func looksRandom(_ label: String) -> Bool {
        let letters = label.filter(\.isLetter)
        let digits = label.filter(\.isNumber)
        guard !letters.isEmpty else { return false }
        // Digit/letter switches: "x7k2p9" switches five times; "office365" once.
        var switches = 0
        var previousWasDigit: Bool?
        for character in label where character.isLetter || character.isNumber {
            let isDigit = character.isNumber
            if let previous = previousWasDigit, previous != isDigit { switches += 1 }
            previousWasDigit = isDigit
        }
        if digits.count >= 3 && switches >= 4 { return true }
        let vowels = letters.filter { "aeiouy".contains($0) }
        if Double(vowels.count) / Double(letters.count) < 0.2 { return true }
        var run = 0, longest = 0
        for character in letters {
            run = "aeiouy".contains(character) ? 0 : run + 1
            longest = max(longest, run)
        }
        return longest >= 6
    }
}
