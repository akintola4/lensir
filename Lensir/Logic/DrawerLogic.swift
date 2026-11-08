//
//  DrawerLogic.swift
//  Lensir
//
//  The drawers' physics, as plain functions. Two phases, like Vaul (the
//  drawer behind shadcn/ui's Drawer): while the finger is down the drawer
//  is the finger, 1:1, rubber-banding past the top; when it lifts, a
//  spring seeded with the finger's speed finishes the move, with a little
//  bounce only if a drag threw it. The dim and the background follow its
//  height, so they're always exactly as far along as the drawer is.
//
//  Heights are measured up from the bottom edge of the screen: 0 is closed.
//

import CoreGraphics
import SwiftUI

nonisolated enum DrawerSnap: Equatable, Sendable {
    case dismissed, compact, expanded
}

/// The spring a drawer moves with: how long, how much it bounces, and the
/// speed it starts at (points per second, positive upward).
nonisolated struct DrawerSpring: Equatable, Sendable {
    var duration: Double
    var bounce: Double
    var velocity: CGFloat
}

/// One move of the drawer from one height to another on a spring. Sampled
/// at any time since it started, so the drawer can be caught mid-way and
/// picked up exactly where it is.
nonisolated struct DrawerFlight: Equatable, Sendable {
    var from: CGFloat
    var to: CGFloat
    var spring: DrawerSpring
}

nonisolated enum DrawerLogic {
    // MARK: Tunables

    /// How far ahead a throw is projected, in seconds of its release speed,
    /// to pick between compact and expanded. Close to UIScrollView's normal
    /// deceleration over a short distance.
    static let projection: CGFloat = 0.2
    /// A release faster than this (points per second) is a flick: it moves
    /// one step in its direction even if the finger barely moved.
    static let flickVelocity: CGFloat = 500
    /// Let go this far below compact, as a share of compact's height, and
    /// the drawer closes however slowly it was moving.
    static let dismissFraction: CGFloat = 0.4
    /// Past the top the drawer gives less and less, and never more than this.
    static let rubberBandLimit: CGFloat = 72
    /// How much the first points past the top give: iOS's scroll views use 0.55.
    static let rubberBandStiffness: CGFloat = 0.55
    /// Rising or changing height.
    static let openDuration = 0.4
    /// Leaving shouldn't take as long as arriving.
    static let closeDuration = 0.3
    /// Let go short of anywhere new: back quickly, not slowly disagreeing.
    static let snapBackDuration = 0.25
    /// A drag throws the drawer, so it lands with a little bounce. A tap,
    /// a button or VoiceOver's escape throws nothing, so they get none.
    static let dragBounce = 0.15
    /// Reduce Motion: the finger still moves it 1:1, but letting go just
    /// eases it into place, without the throw or the bounce.
    static let reducedMotionDuration = 0.2
    /// A release faster than this is treated as this, so a wild flick
    /// can't shoot the drawer off the top.
    static let maxReleaseVelocity: CGFloat = 4000
    /// How dark the camera gets with the drawer fully open.
    static let dimMax = 0.7

    // MARK: Tracking

    /// Height while dragging. Follows the finger exactly below the expanded
    /// height; above it, every extra point of finger travel gives less.
    static func height(start: CGFloat, translation: CGFloat, expanded: CGFloat) -> CGFloat {
        let raw = start - translation
        if raw <= expanded { return max(0, raw) }
        return expanded + rubberBand(offset: raw - expanded)
    }

    /// iOS's rubber band: how far the drawer moves for `offset` points of
    /// finger travel past the top. Approaches `limit` but never reaches it.
    static func rubberBand(offset: CGFloat, limit: CGFloat = rubberBandLimit) -> CGFloat {
        guard offset > 0 else { return 0 }
        return (1 - 1 / (offset * rubberBandStiffness / limit + 1)) * limit
    }

    // MARK: Release

    /// Whether a release below compact closes the drawer: far enough down
    /// (`offset`, points below compact) or thrown down fast enough
    /// (`velocity`, points per second, positive downward).
    static func shouldDismiss(offset: CGFloat, velocity: CGFloat, compact: CGFloat) -> Bool {
        if offset >= compact * dismissFraction { return true }
        return offset > 0 && velocity >= flickVelocity
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
        if shouldDismiss(offset: compact - height, velocity: -velocity, compact: compact) {
            return .dismissed
        }
        let projected = height + velocity * projection
        return abs(expanded - projected) < abs(compact - projected) ? .expanded : .compact
    }

    /// The spring for a move from `from` to `to`. `velocity` is the speed
    /// the finger let go at, positive upward; only a drag carries it.
    static func releaseSpring(velocity: CGFloat, fromDrag: Bool, from: DrawerSnap, to: DrawerSnap,
                              reduceMotion: Bool = false) -> DrawerSpring {
        if reduceMotion { return DrawerSpring(duration: reducedMotionDuration, bounce: 0, velocity: 0) }
        let thrown = fromDrag ? min(max(velocity, -maxReleaseVelocity), maxReleaseVelocity) : 0
        if to == .dismissed { return DrawerSpring(duration: closeDuration, bounce: 0, velocity: thrown) }
        let bounce = fromDrag ? dragBounce : 0
        if fromDrag && to == from { return DrawerSpring(duration: snapBackDuration, bounce: bounce, velocity: thrown) }
        return DrawerSpring(duration: openDuration, bounce: bounce, velocity: thrown)
    }

    /// Where a flight is `time` seconds in, and how fast it's moving there
    /// (points per second, positive upward). The same spring maths SwiftUI uses.
    static func sample(_ flight: DrawerFlight, at time: Double) -> (height: CGFloat, velocity: CGFloat) {
        let spring = Spring(duration: flight.spring.duration, bounce: flight.spring.bounce)
        let distance = Double(flight.to - flight.from)
        let t = max(time, 0)
        let moved = spring.value(target: distance, initialVelocity: Double(flight.spring.velocity), time: t)
        let speed = spring.velocity(target: distance, initialVelocity: Double(flight.spring.velocity), time: t)
        return (flight.from + CGFloat(moved), CGFloat(speed))
    }

    /// The landing: the first moment the drawer reaches where it's going,
    /// or passes it on a bounce. The detent haptic plays here.
    static func hasArrived(_ flight: DrawerFlight, height: CGFloat) -> Bool {
        if abs(flight.to - height) < 1 { return true }
        return (flight.to - flight.from) * (flight.to - height) < 0
    }

    /// At rest: close enough and slow enough that the last frame can jump
    /// to the exact height without anyone seeing it.
    static func isSettled(_ flight: DrawerFlight, height: CGFloat, velocity: CGFloat) -> Bool {
        abs(flight.to - height) < 0.5 && abs(velocity) < 8
    }

    static func height(of snap: DrawerSnap, compact: CGFloat, expanded: CGFloat) -> CGFloat {
        switch snap {
        case .dismissed: 0
        case .compact: compact
        case .expanded: expanded
        }
    }

    // MARK: Linked values

    /// How far the drawer is between closed (0) and expanded (1).
    static func progress(height: CGFloat, expanded: CGFloat) -> CGFloat {
        guard expanded > 0 else { return 0 }
        return min(max(height / expanded, 0), 1)
    }

    /// The camera dims further as the drawer rises: `base` when closed,
    /// `dimMax` when fully open. Driven by the drawer's height, so it is
    /// exactly as dark as the drawer is open, mid-drag and mid-spring.
    static func dimOpacity(progress: CGFloat, base: Double) -> Double {
        base + (dimMax - base) * Double(min(max(progress, 0), 1))
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
