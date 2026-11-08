//
//  CheckChips.swift
//  Lensir
//
//  The checks as a row of chips under a link: every check at once, the
//  failed ones first, then the ones that passed, each group in its usual
//  order. They arrive one after another as the drawer lands. The timing
//  is here so it can be tested; the chips are drawn in ResultDrawer.
//  Decided in docs/decisions/checks.md.
//

import Foundation

nonisolated enum CheckChips {
    /// Failures first, then passes, keeping the order within each.
    static func ordered(_ report: SafetyReport) -> [CheckItem] {
        let all = ResultDetails.checks(for: report)
        return all.filter { !$0.passed } + all.filter(\.passed)
    }

    /// Seconds between one chip starting and the next.
    static let stagger = 0.045
    /// Each chip's spring.
    static let duration = 0.32
    static let bounce = 0.12
    /// A chip starts at this scale, anchored at its leading edge, and grows to 1.
    static let startScale = 0.94
    /// The chips start once the drawer is this far up to compact, so they
    /// arrive with it rather than after it.
    static let lead = 0.85

    static func delay(for index: Int) -> Double {
        stagger * Double(max(index, 0))
    }

    /// The drawer has risen far enough for the chips to start.
    static func hasLanded(height: Double, compact: Double) -> Bool {
        compact > 0 && height >= compact * lead
    }
}
