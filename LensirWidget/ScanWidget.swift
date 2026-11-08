//
//  ScanWidget.swift
//  LensirWidget
//
//  The Lock Screen widget: Lensir's mark, and a tap opens the scanner through
//  lensir://scan. It shows nothing that changes, so one entry lasts forever.
//

import SwiftUI
import WidgetKit

struct ScanEntry: TimelineEntry {
    let date: Date
}

struct ScanProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScanEntry {
        ScanEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScanEntry) -> Void) {
        completion(ScanEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScanEntry>) -> Void) {
        completion(Timeline(entries: [ScanEntry(date: .now)], policy: .never))
    }
}

struct ScanWidget: Widget {
    let kind = "LensirScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ScanProvider()) { _ in
            ScanWidgetEntryView()
                .widgetURL(LensirLink.scan.url)
        }
        .configurationDisplayName("Scan")
        .description("Opens Lensir on the camera.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct ScanWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ScanWidgetView(family: family)
            .containerBackground(for: .widget) {
                if family == .accessoryCircular { AccessoryWidgetBackground() }
            }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    ScanWidget()
} timeline: {
    ScanEntry(date: .now)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ScanWidget()
} timeline: {
    ScanEntry(date: .now)
}
