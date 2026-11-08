//
//  SplashLogic.swift
//  Lensir
//
//  The opening animation, "focus lock", as plain functions of time so it's
//  tuned in one place and tested. It starts on the launch screen's mark
//  (four brackets and a lens dot on black). The brackets breathe outward as
//  if hunting for focus, snap in tight with a haptic while the dot flashes
//  and a ring pulses, then grow out into the scanner's own viewfinder while
//  the camera fades in behind them. The brackets are the scanner overlay's
//  brackets the whole way, so the last frame is the scanner, not a copy.
//

import SwiftUI

nonisolated enum SplashLogic {
    // MARK: - The mark

    /// The launch screen's mark, in points. LaunchMark.svg is drawn from these
    /// numbers (and tested against them), so the hand-off doesn't jump.
    enum Mark {
        /// The brackets' centre line: a square this wide.
        static let side: CGFloat = 111
        static let stroke: CGFloat = 5
        static let cornerRadius: CGFloat = 18
        static let arm: CGFloat = 32
        static let dotRadius: CGFloat = 11
        /// The SVG's size: the square plus half a stroke each side. 116 is
        /// even, so on every iPhone width and height the edges land on whole
        /// points and the launch image isn't resampled.
        static var imageSide: CGFloat { side + stroke }
    }

    /// How much wider the brackets get while hunting.
    static let huntGrowth: CGFloat = 0.45
    /// How tight they lock, against the mark's size.
    static let lockScale: CGFloat = 0.78
    /// The dot dims to this while hunting.
    static let huntDotOpacity = 0.5
    /// The dot's flash at the lock, against its resting size.
    static let flashScale: CGFloat = 1.4
    /// The ring's furthest reach, against the dot's radius, and how faint it starts.
    static let ringReach: CGFloat = 3.2
    static let ringStartOpacity = 0.45

    /// Phase lengths in seconds, at normal speed.
    struct Timeline: Equatable {
        var hunt = 0.18
        var lock = 0.18
        var grow = 0.40

        func slowed(by factor: Double) -> Timeline {
            Timeline(hunt: hunt * factor, lock: lock * factor, grow: grow * factor)
        }

        /// The lock starts here; the haptic fires here.
        var lockStarts: Double { hunt }
        var growStarts: Double { hunt + lock }
        var total: Double { growStarts + grow }
    }

    /// Reduce Motion: the mark holds with the credit, then cross-fades.
    struct StillTimeline: Equatable {
        var hold = 0.45
        var fade = 0.25
        var total: Double { hold + fade }
    }

    // MARK: - Brackets

    /// The brackets' frame and stroke at `t`, centred on the screen until they
    /// grow into the scanner's window. At the end it's exactly the scanner's
    /// own Looking frame, at its own 4 pt stroke.
    static func brackets(at t: Double, in timeline: Timeline, screen: CGSize) -> (frame: BracketFrame, stroke: CGFloat) {
        let centre = CGPoint(x: screen.width / 2, y: screen.height / 2)
        let rest = Mark.side
        let wide = rest * (1 + huntGrowth)
        let tight = rest * lockScale

        if t < timeline.lockStarts {
            let side = rest + (wide - rest) * CGFloat(easeInOut(progress(t, over: timeline.hunt)))
            return (square(side, around: centre), Mark.stroke)
        }
        if t < timeline.growStarts {
            let p = lockCurve(progress(t - timeline.lockStarts, over: timeline.lock))
            return (square(wide + (tight - wide) * CGFloat(p), around: centre), Mark.stroke)
        }
        let target = ScanGeometry.lookingFrame(in: screen)
        // Not a blend that should come out equal: the scanner's own frame.
        if t >= timeline.total { return (target, scannerStroke) }
        let start = square(tight, around: centre)
        let p = CGFloat(growCurve.value(at: progress(t - timeline.growStarts, over: timeline.grow)))
        let rect = CGRect(x: lerp(start.rect.minX, target.rect.minX, p),
                          y: lerp(start.rect.minY, target.rect.minY, p),
                          width: lerp(start.rect.width, target.rect.width, p),
                          height: lerp(start.rect.height, target.rect.height, p))
        return (BracketFrame(rect: rect, cornerRadius: lerp(Mark.cornerRadius, target.cornerRadius, p),
                             arm: lerp(Mark.arm, target.arm, p)),
                lerp(Mark.stroke, scannerStroke, p))
    }

    /// The scanner overlay's bracket stroke.
    static let scannerStroke: CGFloat = 4

    /// The mark's frame, centred on a screen of this size.
    static func markFrame(screen: CGSize) -> BracketFrame {
        square(Mark.side, around: CGPoint(x: screen.width / 2, y: screen.height / 2))
    }

    private static func square(_ side: CGFloat, around centre: CGPoint) -> BracketFrame {
        BracketFrame(rect: CGRect(x: centre.x - side / 2, y: centre.y - side / 2, width: side, height: side),
                     cornerRadius: Mark.cornerRadius, arm: Mark.arm)
    }

    // MARK: - Dot and ring

    /// Dims while hunting, back to full at the lock, gone in the first half
    /// of the grow.
    static func dotOpacity(at t: Double, in timeline: Timeline) -> Double {
        if t < timeline.lockStarts {
            return 1 - (1 - huntDotOpacity) * easeInOut(progress(t, over: timeline.hunt))
        }
        if t < timeline.growStarts {
            return huntDotOpacity + (1 - huntDotOpacity) * min(progress(t - timeline.lockStarts, over: timeline.lock * 0.3), 1)
        }
        return 1 - easeInOut(progress(t - timeline.growStarts, over: timeline.grow * 0.5))
    }

    /// The flash: up to `flashScale` early in the lock and back down by its end.
    static func dotScale(at t: Double, in timeline: Timeline) -> CGFloat {
        guard t >= timeline.lockStarts, t < timeline.growStarts else { return 1 }
        let u = progress(t - timeline.lockStarts, over: timeline.lock)
        return 1 + (flashScale - 1) * CGFloat(sin(.pi * u))
    }

    /// One faint ring out from the dot during the lock.
    static func ring(at t: Double, in timeline: Timeline) -> (radius: CGFloat, opacity: Double) {
        guard t >= timeline.lockStarts else { return (Mark.dotRadius, 0) }
        let u = progress(t - timeline.lockStarts, over: timeline.lock * 1.5)
        let reach = 1 - pow(1 - u, 3)
        return (Mark.dotRadius * (1 + (ringReach - 1) * CGFloat(reach)), ringStartOpacity * (1 - u))
    }

    // MARK: - The scanner coming in

    /// The camera, its dim, the wordmark and the buttons: hidden on black
    /// until the grow, fully in by the end.
    static func sceneOpacity(at t: Double, in timeline: Timeline) -> Double {
        growCurve.value(at: progress(t - timeline.growStarts, over: timeline.grow))
    }

    /// "Made by DEVAKINTOLA": in with the hunt, out in the first half of the
    /// grow, before the scanner's own controls are more than half in.
    static func creditOpacity(at t: Double, in timeline: Timeline) -> Double {
        min(easeInOut(progress(t, over: timeline.hunt)),
            1 - easeInOut(progress(t - timeline.growStarts, over: timeline.grow * 0.5)))
    }

    static func stillCreditOpacity(at t: Double, in timeline: StillTimeline) -> Double {
        min(progress(t, over: 0.15), 1 - progress(t - timeline.hold, over: timeline.fade))
    }

    static func stillSceneOpacity(at t: Double, in timeline: StillTimeline) -> Double {
        easeInOut(progress(t - timeline.hold, over: timeline.fade))
    }

    // MARK: - Curves

    /// A stiff spring released from rest: one small overshoot, then still.
    /// Damping 0.7 of critical; it ends exactly on 1.
    static func lockCurve(_ u: Double) -> Double {
        let zeta = 0.7, natural = 11.0
        let decay = zeta * natural, damped = natural * (1 - zeta * zeta).squareRoot()
        func raw(_ u: Double) -> Double {
            1 - exp(-decay * u) * (cos(damped * u) + decay / damped * sin(damped * u))
        }
        return raw(u) + u * (1 - raw(1))
    }

    /// Fast start, long soft landing, so growing into the viewfinder reads as
    /// a push forward rather than a slide.
    static let growCurve = UnitCurve.bezier(startControlPoint: UnitPoint(x: 0.2, y: 0.8),
                                            endControlPoint: UnitPoint(x: 0.2, y: 1))

    static func easeInOut(_ u: Double) -> Double {
        u * u * (3 - 2 * u)
    }

    static func progress(_ elapsed: Double, over duration: Double) -> Double {
        guard duration > 0 else { return elapsed >= 0 ? 1 : 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private static func lerp(_ a: CGFloat, _ b: CGFloat, _ p: CGFloat) -> CGFloat {
        a + (b - a) * p
    }
}

/// Everything the opening animation sets on one frame.
nonisolated struct SplashFrame: Equatable, Sendable {
    /// The scanner overlay's brackets.
    var brackets: BracketFrame
    var stroke: CGFloat
    var bracketOpacity: Double
    /// Camera, dim, wordmark and buttons.
    var scene: Double
    var credit: Double
    var dotCentre: CGPoint
    var dotRadius: CGFloat
    var dotOpacity: Double
    var ringRadius: CGFloat
    var ringOpacity: Double
    /// Reduce Motion only: the launch mark, held, fading out over the scanner.
    var stillMark: BracketFrame?
    var stillMarkOpacity: Double = 0

    static func moving(at t: Double, in timeline: SplashLogic.Timeline, screen: CGSize) -> SplashFrame {
        let (frame, stroke) = SplashLogic.brackets(at: t, in: timeline, screen: screen)
        let ring = SplashLogic.ring(at: t, in: timeline)
        return SplashFrame(
            brackets: frame, stroke: stroke, bracketOpacity: 1,
            scene: SplashLogic.sceneOpacity(at: t, in: timeline),
            credit: SplashLogic.creditOpacity(at: t, in: timeline),
            dotCentre: CGPoint(x: frame.rect.midX, y: frame.rect.midY),
            dotRadius: SplashLogic.Mark.dotRadius * SplashLogic.dotScale(at: t, in: timeline),
            dotOpacity: SplashLogic.dotOpacity(at: t, in: timeline),
            ringRadius: ring.radius, ringOpacity: ring.opacity
        )
    }

    /// Reduce Motion: no breathing, snap or growth. The mark holds with the
    /// credit, then the scanner cross-fades in over it.
    static func still(at t: Double, in timeline: SplashLogic.StillTimeline, screen: CGSize) -> SplashFrame {
        let scene = SplashLogic.stillSceneOpacity(at: t, in: timeline)
        let mark = SplashLogic.markFrame(screen: screen)
        return SplashFrame(
            brackets: ScanGeometry.lookingFrame(in: screen), stroke: SplashLogic.scannerStroke, bracketOpacity: scene,
            scene: scene,
            credit: SplashLogic.stillCreditOpacity(at: t, in: timeline),
            dotCentre: CGPoint(x: mark.rect.midX, y: mark.rect.midY),
            dotRadius: SplashLogic.Mark.dotRadius, dotOpacity: 1 - scene,
            ringRadius: SplashLogic.Mark.dotRadius, ringOpacity: 0,
            stillMark: mark, stillMarkOpacity: 1 - scene
        )
    }
}
