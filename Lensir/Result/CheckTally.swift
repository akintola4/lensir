//
//  CheckTally.swift
//  Lensir
//
//  A link's checks in the compact drawer. What's wrong comes first, as
//  plain sentences; then every check as a chip, the failed ones red and
//  first, the passed ones quiet. A clean link gets its one line ("Secure
//  · the real paystack.com") over the chips. The chips arrive one after
//  another as the drawer lands, and are simply there with Reduce Motion.
//  VoiceOver reads each chip as its whole check and whether it passed.
//  The order and the timing are in CheckChips.
//

import SwiftUI

struct CheckTally: View {
    var report: SafetyReport
    var drawer: DrawerState
    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if report.isSafe {
                Text(report.safeSummary)
                    .font(Typeface.check)
                    .foregroundStyle(Palette.checkText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(report.findings.enumerated()), id: \.offset) { _, finding in
                        Text(finding.message)
                            .font(Typeface.check)
                            .foregroundStyle(Palette.warningText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Warning. " + report.findings.map(\.message).joined(separator: " "))
            }
            ChipFlow(spacing: 6) {
                ForEach(Array(CheckChips.ordered(report).enumerated()), id: \.offset) { index, check in
                    CheckChip(check: check)
                        .modifier(ChipArrival(index: index, arrived: arrived))
                }
            }
        }
        .background(DrawerLanding(drawer: drawer) { arrived = true })
    }
}

/// One check: a tick or a cross and a word or two.
struct CheckChip: View {
    var check: CheckItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: check.passed ? "checkmark" : "xmark")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(check.passed ? Palette.safe : Palette.warning)
            Text(check.label)
                .font(Typeface.kindLabel)
                .foregroundStyle(check.passed ? Palette.checkText : Palette.warningText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(check.passed ? Palette.raised : Palette.failChip))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(check.title): \(check.passed ? "passed" : "failed")")
    }
}

/// Fades a chip in from slightly smaller, a beat after the one before it.
private struct ChipArrival: ViewModifier {
    var index: Int
    var arrived: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shown = arrived || reduceMotion
        content
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : CheckChips.startScale, anchor: .leading)
            .animation(reduceMotion ? nil : .spring(duration: CheckChips.duration, bounce: CheckChips.bounce)
                .delay(CheckChips.delay(for: index)), value: arrived)
    }
}

/// Calls `onLand` once the drawer has risen most of the way to compact, or
/// straight away if it's already there. Reads the drawer's height here, so
/// the frames of the rise redraw only this.
private struct DrawerLanding: View {
    var drawer: DrawerState
    var onLand: () -> Void

    private var landed: Bool {
        drawer.snap != .dismissed && CheckChips.hasLanded(height: drawer.height, compact: drawer.compactHeight)
    }

    var body: some View {
        Color.clear
            .accessibilityHidden(true)
            .onChange(of: landed, initial: true) { if landed { onLand() } }
    }
}

/// Lays chips out in rows, wrapping when the next one won't fit.
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = Self.rows(subviews, width: width, spacing: spacing)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let widest = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? widest, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in Self.rows(subviews, width: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// A chip wider than the row (a long label at the largest text sizes)
    /// gets the row to itself and wraps its label.
    private static func rows(_ subviews: Subviews, width: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > width {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
            }
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, needed > width {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            row.sizes.append(size)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
