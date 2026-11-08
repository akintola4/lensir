//
//  LinkInbox.swift
//  Lensir
//
//  Shared between the app AND the widget extension (which never reads it).
//
//  Where every way into the scanner lands: a lensir:// link from the Lock
//  Screen widget, and OpenScannerIntent from Control Center, the Action
//  Button, Siri, Spotlight and Shortcuts. The scanner watches `latest`.
//

import Foundation
import Observation

@MainActor @Observable
final class LinkInbox {
    static let shared = LinkInbox()

    struct Request: Equatable {
        let link: LensirLink
        /// Counts up, so asking for the scanner twice in a row is two changes.
        let number: Int
    }

    private(set) var latest: Request?

    func receive(_ link: LensirLink) {
        latest = Request(link: link, number: (latest?.number ?? 0) + 1)
    }

    /// True if the URL was a Lensir link.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let link = LensirLink(url: url) else { return false }
        receive(link)
        return true
    }
}
