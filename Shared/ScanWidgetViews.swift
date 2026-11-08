//
//  ScanWidgetViews.swift
//  Lensir
//
//  Shared between the app AND the widget extension.
//
//  The Lock Screen widget's views. They live here rather than in the
//  extension so the tests can render them to the screenshots in the README;
//  the extension adds the tap link and the background.
//
//  The Lock Screen draws widgets in one vibrant colour (or the wallpaper's
//  tint), so everything is a plain white shape: the brackets are stroked,
//  never an image, and stay sharp at any scale.
//

import SwiftUI
import WidgetKit

/// Lensir's mark: the four brackets and the lens dot, in the launch mark's
/// proportions (side 111, corner 18, arm 32, dot 11) with a stroke that holds
/// up at Lock Screen sizes. The stroke sits inside `side`, so with a whole
/// point stroke the straight edges land on pixels at 2× and 3×.
struct LensirMark: View {
    var side: CGFloat
    var stroke: CGFloat

    static let cornerRatio: CGFloat = 18.0 / 111
    static let armRatio: CGFloat = 32.0 / 111
    static let dotRatio: CGFloat = 11.0 / 111

    var body: some View {
        let inset = stroke / 2
        let frame = BracketFrame(
            rect: CGRect(x: inset, y: inset, width: side - stroke, height: side - stroke),
            cornerRadius: side * Self.cornerRatio,
            arm: side * Self.armRatio
        )
        // Whole points, so the dot's edge doesn't land between pixels.
        let dot = (side * Self.dotRatio * 2).rounded()
        ZStack {
            BracketsShape(frame: frame)
                .stroke(.white, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
            Circle()
                .fill(.white)
                .frame(width: dot, height: dot)
        }
        .frame(width: side, height: side)
    }
}

struct ScanWidgetView: View {
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: ScanRectangularWidget()
            default: ScanCircularWidget()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan with Lensir")
        .accessibilityAddTraits(.isButton)
    }
}

/// Just the mark, centred in the disc.
struct ScanCircularWidget: View {
    var body: some View {
        LensirMark(side: 40, stroke: 3)
            .widgetAccentable()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The mark and what tapping does.
struct ScanRectangularWidget: View {
    var body: some View {
        HStack(spacing: 10) {
            LensirMark(side: 34, stroke: 3)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text("Scan a code")
                    .font(.system(.headline, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Lensir")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
