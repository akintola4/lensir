//
//  DrawerState.swift
//  Lensir
//
//  The drawer's live height and where it's headed. The maths is in
//  DrawerLogic; this applies it, animating with a spring that starts at the
//  speed the finger let go.
//

import SwiftUI

@Observable
final class DrawerState {
    /// Visible height above the bottom edge of the screen.
    var height: CGFloat = 0
    private(set) var snap: DrawerSnap = .dismissed
    private(set) var compactHeight: CGFloat = 0
    private(set) var expandedHeight: CGFloat = 0
    var reduceMotion = false
    /// The last time a drag or a grabber tap let go, and where it sent the
    /// drawer. Drives the detent haptic.
    private(set) var lastSettle: Settle?

    struct Settle: Equatable {
        var count: Int
        var from: DrawerSnap
        var to: DrawerSnap
    }

    /// Where to go once the content has been measured.
    private var pending: (snap: DrawerSnap, animated: Bool)?
    private var dragStart: CGFloat?

    var isDragging: Bool { dragStart != nil }

    /// A new result: start below the edge and rise to `snap` once measured.
    func present(_ snap: DrawerSnap = .compact, animated: Bool = true) {
        height = 0
        self.snap = .dismissed
        compactHeight = 0
        expandedHeight = 0
        pending = (snap, animated)
    }

    /// The content's measured heights. The first measurement opens the
    /// drawer; later ones (a status line appearing, say) keep it in place.
    func measured(compact: CGFloat, expanded: CGFloat) {
        guard compact > 0, abs(compact - compactHeight) > 0.5 || abs(expanded - expandedHeight) > 0.5 else { return }
        compactHeight = compact
        expandedHeight = max(expanded, compact)
        if let pending {
            self.pending = nil
            if pending.animated {
                move(to: pending.snap)
            } else {
                snap = pending.snap
                height = DrawerLogic.height(of: pending.snap, compact: compactHeight, expanded: expandedHeight)
            }
        } else if snap != .dismissed, !isDragging {
            move(to: snap)
        }
    }

    func move(to target: DrawerSnap, velocity: CGFloat = 0, completion: (() -> Void)? = nil) {
        snap = target
        let to = DrawerLogic.height(of: target, compact: compactHeight, expanded: expandedHeight)
        let animation: Animation = reduceMotion
            ? .easeInOut(duration: 0.25)
            : .interpolatingSpring(duration: 0.4, bounce: 0, initialVelocity: DrawerLogic.relativeVelocity(velocity, from: height, to: to))
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            height = to
        } completion: {
            completion?()
        }
    }

    /// A drag or a grabber tap let go: move to `target` and mark it, so the
    /// haptic fires as the spring starts.
    func settle(to target: DrawerSnap, velocity: CGFloat = 0) {
        let from = snap
        move(to: target, velocity: velocity)
        lastSettle = Settle(count: (lastSettle?.count ?? 0) + 1, from: from, to: target)
    }

    func toggle() {
        settle(to: snap == .expanded ? .compact : .expanded)
    }

    func dragChanged(_ translation: CGFloat) {
        if dragStart == nil { dragStart = height }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            height = DrawerLogic.height(start: dragStart ?? height, translation: translation, expanded: expandedHeight)
        }
    }

    /// Where the drag should end up. `velocity` is the gesture's, positive downward.
    func dragEnded(velocity: CGFloat) -> DrawerSnap {
        dragStart = nil
        return DrawerLogic.snap(height: height, velocity: -velocity, compact: compactHeight, expanded: expandedHeight, from: snap)
    }

    // Derived values the screen ties to the drawer's height.

    func dim(base: Double) -> Double {
        DrawerLogic.dimOpacity(height: height, expanded: expandedHeight, base: base)
    }

    /// 0 at compact, 1 at expanded: Details fade in along the way.
    var expansion: CGFloat {
        DrawerLogic.expansion(height: height, compact: compactHeight, expanded: expandedHeight)
    }

    var backgroundScale: CGFloat {
        reduceMotion ? 1 : DrawerLogic.backgroundScale(height: height, compact: compactHeight, expanded: expandedHeight)
    }

    var backgroundRadius: CGFloat {
        reduceMotion ? 0 : DrawerLogic.backgroundRadius(height: height, compact: compactHeight, expanded: expandedHeight)
    }
}
