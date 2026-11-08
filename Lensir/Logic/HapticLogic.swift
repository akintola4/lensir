//
//  HapticLogic.swift
//  Lensir
//
//  Which haptic each event plays, in one place. A new code taps; a risky
//  one plays the system warning instead, as the brackets turn red. The
//  drawer ticks when it lands on a new height, and copying or keeping a
//  code you made ticks lightly.
//  All of it is silent when Haptics is off in settings.
//

import SwiftUI

nonisolated enum HapticEvent: Equatable, Sendable {
    /// A new code in view. `risky` is the "check this" verdict.
    case detected(risky: Bool)
    /// A drag or a grabber tap let go and the drawer is heading to `to`.
    case drawerSettled(from: DrawerSnap, to: DrawerSnap)
    /// Something went on the clipboard.
    case copied
    /// A code you made went into My codes.
    case kept
}

nonisolated enum HapticLogic {
    static func feedback(for event: HapticEvent, hapticsOn: Bool) -> SensoryFeedback? {
        guard hapticsOn else { return nil }
        switch event {
        case .detected(risky: true): return .warning
        case .detected(risky: false): return .impact(weight: .medium)
        case .drawerSettled(let from, let to):
            // Closing has its own motion; snapping back where it was isn't a change.
            return to == .dismissed || to == from ? nil : .selection
        case .copied, .kept: return .impact(weight: .light)
        }
    }
}
