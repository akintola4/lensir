//
//  HistoryLogic.swift
//  Lensir
//
//  Groups scans by day, newest first, with "Today" and "Yesterday" where
//  they apply, and decides when a repeat scan should update the last entry
//  instead of adding a new one.
//

import Foundation

nonisolated struct HistorySection<Item>: Identifiable {
    var day: Date
    var title: String
    var items: [Item]

    var id: Date { day }
}

nonisolated enum HistoryLogic {
    static func sections<Item>(_ items: [Item], date: (Item) -> Date, now: Date = .now,
                               calendar: Calendar = .current, locale: Locale = .current) -> [HistorySection<Item>] {
        let sorted = items.sorted { date($0) > date($1) }
        var sections: [HistorySection<Item>] = []
        for item in sorted {
            let day = calendar.startOfDay(for: date(item))
            if sections.last?.day == day {
                sections[sections.count - 1].items.append(item)
            } else {
                sections.append(HistorySection(day: day, title: title(for: day, now: now, calendar: calendar, locale: locale), items: [item]))
            }
        }
        return sections
    }

    static func title(for day: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(day, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).day().month(.wide)
        if !calendar.isDate(day, equalTo: now, toGranularity: .year) { style = style.year() }
        return day.formatted(style)
    }

    /// Holding the camera on one code opens it again and again; that's one scan.
    static func isRepeat(payload: String, at date: Date, lastPayload: String?, lastDate: Date?, window: TimeInterval = 60) -> Bool {
        guard let lastPayload, let lastDate else { return false }
        return lastPayload == payload && date.timeIntervalSince(lastDate) < window
    }
}
