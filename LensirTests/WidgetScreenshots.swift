//
//  WidgetScreenshots.swift
//  LensirTests
//
//  Renders the real Lock Screen widget views (Shared/ScanWidgetViews.swift)
//  into the PNGs in docs/screenshots/widgets/, on a stand-in Lock Screen.
//  The Simulator can't add a widget without tapping, so this is how the
//  README gets its pictures. Skipped unless asked for; run
//  scripts/widget-screenshots.sh.
//

import SwiftUI
import Testing
import WidgetKit
@testable import Lensir

@MainActor
@Suite("Widget screenshots", .enabled(if: ProcessInfo.processInfo.environment["LENSIR_WIDGET_SHOTS"] != nil))
struct WidgetScreenshots {
    /// iPhone 17 Pro sizes, in points.
    private static let rectangular = CGSize(width: 172, height: 76)
    private static let circular = CGSize(width: 76, height: 76)
    private static let screenWidth: CGFloat = 402

    private static let output = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "docs/screenshots/widgets")

    @Test func lockScreen() throws {
        let screen = VStack(spacing: 6) {
            Text("Sunday 8 November")
                .font(.system(size: 17, weight: .semibold))
            Text("9:41")
                .font(.system(size: 104, weight: .semibold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 12) {
                lockCircle
                ScanWidgetView(family: .accessoryRectangular)
                    .frame(width: Self.rectangular.width, height: Self.rectangular.height)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 32)
        .frame(width: Self.screenWidth)
        .background(Wallpaper())
        .environment(\.colorScheme, .dark)
        try save(screen, as: "lock.png")
    }

    /// One circular widget, big, to check the brackets' edges.
    @Test func circularCloseUp() throws {
        let view = lockCircle
            .padding(12)
            .background(Wallpaper())
            .environment(\.colorScheme, .dark)
        try save(view, as: "circular.png", scale: 3)
    }

    // MARK: Helpers

    /// `AccessoryWidgetBackground` only draws on a real Lock Screen, so the
    /// stand-in gets the same translucent disc behind it.
    private var lockCircle: some View {
        ScanWidgetView(family: .accessoryCircular)
            .frame(width: Self.circular.width, height: Self.circular.height)
            .background(.white.opacity(0.16), in: .circle)
    }

    private func save(_ view: some View, as name: String, scale: CGFloat = 3) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        let image = try #require(renderer.uiImage)
        let data = try #require(image.pngData())
        try FileManager.default.createDirectory(at: Self.output, withIntermediateDirectories: true)
        try data.write(to: Self.output.appending(path: name))
    }
}

/// A dark gradient standing in for a wallpaper.
private struct Wallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.07, blue: 0.1), Color(red: 0.16, green: 0.22, blue: 0.27)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
