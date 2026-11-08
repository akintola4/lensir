//
//  LinkAddress.swift
//  Lensir
//
//  Splits a link into the parts a person needs to see: scheme, the site, and
//  the rest. Written by hand rather than with URL, because URL quietly
//  rewrites the exact things the safety checks need to look at (Unicode
//  hosts, "@" tricks, backslashes).
//

import Foundation

nonisolated struct LinkAddress: Equatable, Sendable {
    /// Lower-cased, without the colon: "https", "javascript".
    var scheme: String
    /// What sits before an "@" in the authority, if anything.
    var userInfo: String?
    /// As written, lower-cased and percent-decoded; may contain xn-- labels.
    var host: String
    /// The host with xn-- labels decoded, so lookalike letters show as themselves.
    var displayHost: String
    var port: String?
    /// Path, query and fragment, as written.
    var rest: String
    /// The site's own name plus its ending: "paystack.com", "jumia.com.ng".
    var registrableDomain: String
    /// Labels in front of the registrable domain: ["checkout"] for checkout.paystack.com.
    var subdomains: [String]

    var hasAuthority: Bool { !host.isEmpty }

    /// The host as shown in the pill and the sheet title: without "www.".
    var shortHost: String { displayHost.hasPrefix("www.") ? String(displayHost.dropFirst(4)) : displayHost }
    /// Where shortHost starts inside displayHost, for moving highlight ranges.
    var shortHostOffset: Int { displayHost.hasPrefix("www.") ? 4 : 0 }

    /// The site name without its ending: "paystack" for paystack.com.
    var siteLabel: String {
        String(registrableDomain.split(separator: ".").first ?? "")
    }

    init?(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = text.firstIndex(of: ":") else { return nil }
        let scheme = text[..<colon].lowercased()
        guard let first = scheme.first, first.isLetter,
              scheme.allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) }) else { return nil }
        self.scheme = scheme

        var remainder = text[text.index(after: colon)...]
        // Browsers treat "\" like "/" in web addresses, and so do phishers.
        let slashes = remainder.prefix(while: { $0 == "/" || $0 == "\\" })
        guard slashes.count >= 2, scheme == "http" || scheme == "https" else {
            userInfo = nil
            host = ""
            displayHost = ""
            port = nil
            rest = String(remainder)
            registrableDomain = ""
            subdomains = []
            return
        }
        remainder = remainder.dropFirst(slashes.count)
        let authorityEnd = remainder.firstIndex(where: { "/?#\\".contains($0) }) ?? remainder.endIndex
        var authority = String(remainder[..<authorityEnd])
        rest = String(remainder[authorityEnd...])

        if let at = authority.lastIndex(of: "@") {
            userInfo = String(authority[..<at])
            authority = String(authority[authority.index(after: at)...])
        } else {
            userInfo = nil
        }

        var hostPart = authority
        port = nil
        if authority.hasPrefix("["), let close = authority.firstIndex(of: "]") {
            hostPart = String(authority[...close])
            let after = authority[authority.index(after: close)...]
            if after.hasPrefix(":") { port = String(after.dropFirst()) }
        } else if let portColon = authority.lastIndex(of: ":") {
            hostPart = String(authority[..<portColon])
            port = String(authority[authority.index(after: portColon)...])
        }
        let decoded = (hostPart.removingPercentEncoding ?? hostPart).lowercased()
        host = decoded.hasSuffix(".") ? String(decoded.dropLast()) : decoded
        guard !host.isEmpty else { return nil }
        displayHost = Punycode.decodeHost(host)
        (registrableDomain, subdomains) = Self.split(displayHost)
    }

    /// "a.b.paystack.com" → ("paystack.com", ["a", "b"]). IP addresses are
    /// their own registrable domain.
    static func split(_ host: String) -> (String, [String]) {
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 1, !host.hasPrefix("[") else { return (host, []) }
        var take = 2
        if labels.count >= 3, Brands.twoLabelSuffixes.contains(labels.suffix(3).joined(separator: ".")) {
            take = 4
        } else if Brands.twoLabelSuffixes.contains(labels.suffix(2).joined(separator: ".")) {
            take = 3
        }
        take = min(take, labels.count)
        return (labels.suffix(take).joined(separator: "."), Array(labels.dropLast(take)))
    }
}
