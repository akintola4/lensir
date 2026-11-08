//
//  DrawerLogic.swift
//  Lensir
//
//  The result drawer's physics, as plain functions: where it sits while a
//  finger drags it, which point it snaps to when let go, and how the dim
//  and the background follow its height. It works like Vaul (the drawer
//  behind shadcn/ui's Drawer): it follows the finger 1:1, resists past the
//  top, and on release picks the nearest point to where the throw would
//  carry it.
//
//  Heights are measured up from the bottom edge of the screen: 0 is closed.
//

import CoreGraphics

nonisolated enum DrawerSnap: Equatable, Sendable {
    case dismissed, compact, expanded
}

nonisolated enum DrawerLogic {
    /// How far ahead a throw is projected, in seconds of its release speed.
    /// Close to UIScrollView's normal deceleration over a short distance.
    static let projection: CGFloat = 0.2
    /// A release faster than this (points per second) is a flick: it moves
    /// one step in its direction even if the finger barely moved.
    static let flickVelocity: CGFloat = 700

    /// Height while dragging. Follows the finger exactly below the expanded
    /// height; above it, every extra point of finger travel gives less.
    static func height(start: CGFloat, translation: CGFloat, expanded: CGFloat) -> CGFloat {
        let raw = start - translation
        if raw <= expanded { return max(0, raw) }
        return expanded + rubberBand(raw - expanded)
    }

    /// iOS's rubber band: approaches `limit` but never reaches it.
    static func rubberBand(_ overshoot: CGFloat, limit: CGFloat = 120) -> CGFloat {
        guard overshoot > 0 else { return 0 }
        return (1 - 1 / (overshoot * 0.55 / limit + 1)) * limit
    }

    /// Where to go on release. `velocity` is in points per second, positive
    /// when the drawer is moving up (growing).
    ///
    /// A drawer that doesn't `expand` (Make, which has no Details) has one
    /// height: anything that would expand it stays at compact.
    static func snap(height: CGFloat, velocity: CGFloat, compact: CGFloat, expanded: CGFloat, from: DrawerSnap,
                     expands: Bool = true) -> DrawerSnap {
        let snap = nearestSnap(height: height, velocity: velocity, compact: compact, expanded: expanded, from: from)
        return !expands && snap == .expanded ? .compact : snap
    }

    private static func nearestSnap(height: CGFloat, velocity: CGFloat, compact: CGFloat, expanded: CGFloat, from: DrawerSnap) -> DrawerSnap {
        if velocity <= -flickVelocity {
            // A flick down: expanded steps to compact; compact closes.
            return from == .expanded && height > compact * 0.5 ? .compact : .dismissed
        }
        if velocity >= flickVelocity {
            return .expanded
        }
        let projected = height + velocity * projection
        let points: [(DrawerSnap, CGFloat)] = [(.dismissed, 0), (.compact, compact), (.expanded, expanded)]
        return points.min { abs($0.1 - projected) < abs($1.1 - projected) }!.0
    }

    /// The spring's length: 0.4 s to rise or change height, 0.3 s to close,
    /// since leaving shouldn't take as long as arriving.
    static func springDuration(to snap: DrawerSnap) -> Double {
        snap == .dismissed ? 0.3 : 0.4
    }

    static func height(of snap: DrawerSnap, compact: CGFloat, expanded: CGFloat) -> CGFloat {
        switch snap {
        case .dismissed: 0
        case .compact: compact
        case .expanded: expanded
        }
    }

    /// The release speed as a fraction of the distance still to travel, per
    /// second: what SwiftUI's spring wants as its initial velocity, so the
    /// drawer carries on at the speed the finger let go.
    static func relativeVelocity(_ velocity: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
        let distance = to - from
        guard abs(distance) > 0.5 else { return 0 }
        return velocity / distance
    }

    /// How far the drawer is between closed (0) and expanded (1).
    static func progress(height: CGFloat, expanded: CGFloat) -> CGFloat {
        guard expanded > 0 else { return 0 }
        return min(max(height / expanded, 0), 1)
    }

    /// The camera dims further as the drawer rises: `base` when closed,
    /// 0.7 when fully open.
    static func dimOpacity(height: CGFloat, expanded: CGFloat, base: Double) -> Double {
        base + (0.7 - base) * Double(progress(height: height, expanded: expanded))
    }

    /// Between compact and expanded, the camera sinks back from 1 to 0.96
    /// and its corners round, so the open drawer reads as on top.
    static func backgroundScale(height: CGFloat, compact: CGFloat, expanded: CGFloat) -> CGFloat {
        1 - 0.04 * expansion(height: height, compact: compact, expanded: expanded)
    }

    static func backgroundRadius(height: CGFloat, compact: CGFloat, expanded: CGFloat) -> CGFloat {
        24 * expansion(height: height, compact: compact, expanded: expanded)
    }

    /// How far the drawer is between compact (0) and expanded (1).
    static func expansion(height: CGFloat, compact: CGFloat, expanded: CGFloat) -> CGFloat {
        guard expanded > compact else { return 0 }
        return min(max((height - compact) / (expanded - compact), 0), 1)
    }
}

// MARK: - Who owns a drag

/// Whether a finger on the drawer moves the drawer, scrolls its content,
/// or is left alone (sideways drags).
nonisolated enum DragOwner: Equatable, Sendable {
    case drawer, scroll, ignored
}

/// One drag across the drawer, from first movement to release. Pure, so
/// the hand-over between scrolling and moving the drawer is tested.
nonisolated struct DrawerDrag: Equatable, Sendable {
    /// Nil until the finger has moved far enough to tell what it means.
    var owner: DragOwner?
    /// The finger's vertical travel when the drawer took over. The drawer
    /// moves by whatever comes after, so it never jumps.
    var handoff: CGFloat = 0

    /// How far the drawer itself should have moved.
    func drawerTranslation(_ translation: CGFloat) -> CGFloat {
        owner == .drawer ? translation - handoff : 0
    }
}

extension DrawerLogic {
    /// Movement under this is still a tap.
    static let dragThreshold: CGFloat = 8

    /// Works out, or updates, who owns a drag. `translation.height` is
    /// positive downward. `scrollOffset` is how far the Details content is
    /// scrolled; `canScroll` is whether it scrolls at all right now.
    ///
    /// Like Vaul: the header always moves the drawer. Elsewhere, a drag
    /// down moves the drawer once the content is at the top, and a drag up
    /// in compact expands it. If the content is scrolled down, a drag down
    /// scrolls it back first and hands over to the drawer the moment it
    /// reaches the top, carrying on from there.
    static func track(_ drag: DrawerDrag, translation: CGSize, startsInHandle: Bool,
                      scrollOffset: CGFloat, canScroll: Bool) -> DrawerDrag {
        let atTop = scrollOffset <= 0.5
        switch drag.owner {
        case .some(.scroll):
            guard atTop, translation.height > 0 else { return drag }
            return DrawerDrag(owner: .drawer, handoff: translation.height)
        case .some:
            return drag
        case nil:
            let dx = translation.width, dy = translation.height
            guard (dx * dx + dy * dy).squareRoot() >= dragThreshold else { return drag }
            if abs(dx) > abs(dy) { return DrawerDrag(owner: .ignored) }
            if startsInHandle || !canScroll { return DrawerDrag(owner: .drawer, handoff: dy) }
            if dy > 0 { return atTop ? DrawerDrag(owner: .drawer, handoff: dy) : DrawerDrag(owner: .scroll) }
            return DrawerDrag(owner: .scroll)
        }
    }
}
