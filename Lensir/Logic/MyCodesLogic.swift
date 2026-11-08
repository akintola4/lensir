//
//  MyCodesLogic.swift
//  Lensir
//
//  The rules for My codes: keeping a code twice doesn't make two rows,
//  renaming to nothing keeps the old name, and each row says what kind of
//  code it is and when you made it.
//

import Foundation

nonisolated enum MyCodesLogic {
    static let nameLimit = 60

    enum KeepPlan: Equatable {
        /// A new row.
        case insert(name: String)
        /// Already kept: nothing to add.
        case alreadyKept
    }

    static func keep(raw: String, name: String, keptPayloads: [String]) -> KeepPlan {
        keptPayloads.contains(raw) ? .alreadyKept : .insert(name: cleanName(name, fallback: "My code"))
    }

    /// A rename trimmed and capped; an empty one keeps `current`.
    static func renamed(current: String, to input: String) -> String {
        cleanName(input, fallback: current)
    }

    private static func cleanName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(nameLimit))
    }

    /// "Wi-Fi · 8 Nov", with the year when it isn't this one.
    static func subtitle(raw: String, date: Date, now: Date = .now, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let kind = CodeKind(PayloadParser.parse(raw)).title
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .day().month(.abbreviated)
        if !calendar.isDate(date, equalTo: now, toGranularity: .year) { style = style.year() }
        return "\(kind) · \(date.formatted(style))"
    }
}

/// Turns the screen up while a code is showing and back to where it was
/// after. It remembers the brightness you had once, so showing, leaving
/// the app and coming back never ratchets it to full for good.
nonisolated struct BrightnessLock: Equatable, Sendable {
    static let showing: Double = 1
    private(set) var saved: Double?

    /// The brightness to set, or nil if it's already up.
    mutating func raise(from current: Double) -> Double? {
        guard saved == nil else { return nil }
        saved = current
        return Self.showing
    }

    /// The brightness to go back to, or nil if it was never raised.
    mutating func restore() -> Double? {
        defer { saved = nil }
        return saved
    }
}
