//
//  DrawerState.swift
//  Lensir
//
//  The drawer's live height and where it's headed. The maths is in
//  DrawerLogic; this applies it.
//
//  `height` is always where the drawer is on screen, never just where it's
//  going: a finger writes it while dragging, and a spring writes it every
//  frame after (from a display link, not a SwiftUI animation). So a finger
//  that lands mid-flight catches the drawer exactly where it is, the dim
//  and the background follow the same number all the way, and the detent
//  haptic plays the frame the drawer lands.
//

import QuartzCore
import SwiftUI

@Observable
final class DrawerState {
    /// Visible height above the bottom edge of the screen.
    private(set) var height: CGFloat = 0
    private(set) var snap: DrawerSnap = .dismissed
    private(set) var compactHeight: CGFloat = 0
    private(set) var expandedHeight: CGFloat = 0
    var reduceMotion = false
    /// The last time a drag or a grabber tap landed the drawer, and where.
    /// Drives the detent haptic.
    private(set) var lastSettle: Settle?
    /// A spring is moving the drawer, or a finger has stopped one. While
    /// it's true a touch anywhere on the drawer catches it.
    private(set) var isCatchable = false

    struct Settle: Equatable {
        var count: Int
        var from: DrawerSnap
        var to: DrawerSnap
    }

    /// The spring that's moving the drawer, when it started, and what to do
    /// when it lands and when it's done.
    private struct Flight {
        var path: DrawerFlight
        var start: CFTimeInterval
        var settle: (from: DrawerSnap, to: DrawerSnap)?
        var arrived = false
        var completion: (() -> Void)?
    }

    @ObservationIgnored private var flight: Flight?
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private let ticker = FrameTicker()
    @ObservationIgnored private let clock: () -> CFTimeInterval
    @ObservationIgnored private let drivesItself: Bool
    /// Where to go once the content has been measured.
    @ObservationIgnored private var pending: (snap: DrawerSnap, animated: Bool)?
    @ObservationIgnored private var dragStart: CGFloat?
    /// A finger stopped a moving drawer and hasn't dragged it yet.
    @ObservationIgnored private var held = false

    /// `drivesItself` false leaves the frames to `advance(to:)`, for tests.
    /// `slowdown` runs the springs that many times slower.
    init(clock: @escaping () -> CFTimeInterval = CACurrentMediaTime, drivesItself: Bool = true, slowdown: Double = 1) {
        self.clock = { clock() / slowdown }
        self.drivesItself = drivesItself
        ticker.onFrame = { [weak self] time in self?.advance(to: time / slowdown) }
    }

    var isDragging: Bool { dragStart != nil }
    var isMoving: Bool { flight != nil }

    /// A new result: start below the edge and rise to `snap` once measured.
    func present(_ snap: DrawerSnap = .compact, animated: Bool = true) {
        stop()
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
        } else if snap != .dismissed, !isDragging, !held {
            move(to: snap)
        }
    }

    /// Spring to `target`. `velocity` (points per second, positive upward)
    /// is the finger's at release, and only counts `fromDrag`; a move with
    /// no finger behind it keeps whatever speed the drawer already had.
    /// `completion` runs once it comes to rest there, and not at all if
    /// something else moves it first.
    func move(to target: DrawerSnap, velocity: CGFloat = 0, fromDrag: Bool = false, completion: (() -> Void)? = nil) {
        fly(to: target, velocity: velocity, fromDrag: fromDrag, settles: false, completion: completion)
    }

    /// A drag or a grabber tap let go: move to `target`, and play the detent
    /// haptic when it lands.
    func settle(to target: DrawerSnap, velocity: CGFloat = 0, fromDrag: Bool = false) {
        fly(to: target, velocity: velocity, fromDrag: fromDrag, settles: true, completion: nil)
    }

    func toggle() {
        settle(to: snap == .expanded ? .compact : .expanded)
    }

    private func fly(to target: DrawerSnap, velocity: CGFloat, fromDrag: Bool, settles: Bool, completion: (() -> Void)?) {
        let from = snap
        let carried = flight.map { DrawerLogic.sample($0.path, at: clock() - $0.start).velocity } ?? 0
        held = false
        snap = target
        let to = DrawerLogic.height(of: target, compact: compactHeight, expanded: expandedHeight)
        var spring = DrawerLogic.releaseSpring(velocity: velocity, fromDrag: fromDrag, from: from, to: target,
                                               reduceMotion: reduceMotion)
        if !fromDrag && !reduceMotion { spring.velocity = carried }
        flight = Flight(path: DrawerFlight(from: height, to: to, spring: spring), start: clock(),
                        settle: settles ? (from, target) : nil, completion: completion)
        isCatchable = true
        startLink()
    }

    /// One frame of the spring.
    func advance(to time: CFTimeInterval) {
        guard var current = flight else { return }
        let sample = DrawerLogic.sample(current.path, at: time - current.start)
        setHeight(sample.height)
        if !current.arrived, DrawerLogic.hasArrived(current.path, height: sample.height) {
            current.arrived = true
            if let settle = current.settle {
                lastSettle = Settle(count: (lastSettle?.count ?? 0) + 1, from: settle.from, to: settle.to)
            }
        }
        if DrawerLogic.isSettled(current.path, height: sample.height, velocity: sample.velocity) {
            setHeight(current.path.to)
            stop()
            current.completion?()
        } else {
            flight = current
        }
    }

    // MARK: Fingers

    /// A finger came down while the drawer was moving: stop it under the finger.
    func hold() {
        guard flight != nil, !isDragging else { return }
        if let current = flight { setHeight(DrawerLogic.sample(current.path, at: clock() - current.start).height) }
        stop()
        held = true
        isCatchable = true
    }

    /// The finger that held it lifted without dragging. Where it should go
    /// now, or nil if it wasn't holding it.
    func releaseHold(expands: Bool = true) -> DrawerSnap? {
        guard held else { return nil }
        held = false
        isCatchable = false
        return DrawerLogic.snap(height: height, velocity: 0, compact: compactHeight, expanded: expandedHeight,
                                from: snap, expands: expands)
    }

    func dragChanged(_ translation: CGFloat) {
        if dragStart == nil {
            // Caught mid-flight: carry on from exactly where it is.
            if let current = flight { setHeight(DrawerLogic.sample(current.path, at: clock() - current.start).height) }
            stop()
            held = false
            isCatchable = false
            dragStart = height
        }
        setHeight(DrawerLogic.height(start: dragStart ?? height, translation: translation, expanded: expandedHeight))
    }

    /// Where the drag should end up. `velocity` is the gesture's, positive downward.
    func dragEnded(velocity: CGFloat, expands: Bool = true) -> DrawerSnap {
        dragStart = nil
        return DrawerLogic.snap(height: height, velocity: -velocity, compact: compactHeight, expanded: expandedHeight,
                                from: snap, expands: expands)
    }

    // MARK: Frames

    private func setHeight(_ value: CGFloat) {
        guard value != height else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { height = value }
    }

    private func stop() {
        flight = nil
        isCatchable = held
        link?.invalidate()
        link = nil
    }

    private func startLink() {
        guard drivesItself, link == nil else { return }
        let link = CADisplayLink(target: ticker, selector: #selector(FrameTicker.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    // Derived values the screen ties to the drawer's height.

    func dim(base: Double) -> Double {
        DrawerLogic.dimOpacity(progress: DrawerLogic.progress(height: height, expanded: expandedHeight), base: base)
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

/// The display link's target. A separate object so the link, which keeps
/// its target alive, doesn't keep the drawer alive.
private final class FrameTicker: NSObject {
    var onFrame: (CFTimeInterval) -> Void = { _ in }

    @objc func tick(_ link: CADisplayLink) {
        onFrame(link.targetTimestamp)
    }
}
