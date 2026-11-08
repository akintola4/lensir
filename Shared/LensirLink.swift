//
//  LensirLink.swift
//  Lensir
//
//  Shared between the app AND the widget extension.
//
//  The app's one deep link, lensir://scan: open on the live scanner with
//  nothing in front of it. The Lock Screen widget opens it, and the Control
//  Center control, the Action Button and Siri end up in the same place.
//

import Foundation

nonisolated enum LensirLink: Equatable, Sendable {
    case scan

    static let scheme = "lensir"

    /// Reads `lensir://scan`. The scheme and host are case-insensitive, as
    /// URLs are; a trailing slash, a query or a fragment are ignored. Anything
    /// else is nil, so an unknown link opens the app as it was.
    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        // `lensir://scan` puts "scan" in the host; `lensir:scan` in the path.
        let name = (components.host ?? components.path).lowercased()
        let rest = components.host == nil ? "" : components.path
        guard rest.isEmpty || rest == "/" else { return nil }
        switch name {
        case "scan": self = .scan
        default: return nil
        }
    }

    var url: URL {
        switch self {
        case .scan: URL(string: "\(Self.scheme)://scan")!
        }
    }
}
