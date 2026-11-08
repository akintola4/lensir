//
//  SplashLogicTests.swift
//  LensirTests
//
//  The opening animation: phases in order and inside the budget, a first
//  frame that matches the launch screen's image, the hunt, the lock's one
//  small overshoot, an end state that is exactly the scanner's Looking
//  brackets, the credit coming and going, and the Reduce Motion path.
//

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import Lensir

private let screen = CGSize(width: 402, height: 874)   // iPhone 17 Pro
private let timeline = SplashLogic.Timeline()

private func close(_ a: Double, _ b: Double, within tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

private func side(at t: Double) -> CGFloat {
    SplashLogic.brackets(at: t, in: timeline, screen: screen).frame.rect.width
}

@Suite("Opening animation")
struct SplashLogicTests {
    // MARK: - Timeline

    @Test func phasesInOrderWithinBudget() {
        #expect(timeline.lockStarts < timeline.growStarts)
        #expect(timeline.growStarts < timeline.total)
        #expect(close(timeline.total, 0.76))
        #expect(close(timeline.slowed(by: 4).total, 3.04))
    }

    // MARK: - Launch screen hand-off

    @Test func launchImageMatchesTheMark() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Lensir/Assets.xcassets/LaunchMark.imageset/LaunchMark.svg")
        let svg = try String(contentsOf: url, encoding: .utf8)
        func attribute(_ name: String, in tag: String) throws -> String {
            let match = try #require(svg.firstMatch(of: try Regex("<\(tag)[^>]* \(name)=\"([^\"]+)\"")))
            return try #require(match.output[1].substring.map(String.init))
        }
        let mark = SplashLogic.Mark.self
        #expect(Double(try attribute("width", in: "svg")) == Double(mark.imageSide))
        #expect(Double(try attribute("height", in: "svg")) == Double(mark.imageSide))
        #expect(try attribute("viewBox", in: "svg") == "0 0 \(Int(mark.imageSide)) \(Int(mark.imageSide))")
        #expect(Double(try attribute("r", in: "circle")) == Double(mark.dotRadius))
        #expect(Double(try attribute("cx", in: "circle")) == Double(mark.imageSide / 2))

        // The first bracket's outline: the outer edge of the arm, then the
        // corner's outer arc, i.e. the 5 pt stroke around the shape's path.
        let d = try attribute("d", in: "path")
        let o = mark.stroke / 2, h = mark.stroke / 2
        #expect(d.hasPrefix("M\(fmt(o - h)) \(fmt(o + mark.arm))L\(fmt(o - h)) \(fmt(o + mark.cornerRadius))A\(fmt(mark.cornerRadius + h)) \(fmt(mark.cornerRadius + h))"))
        // Inner arc and round caps.
        #expect(d.contains("A\(fmt(mark.cornerRadius - h)) \(fmt(mark.cornerRadius - h))"))
        #expect(d.contains("A\(fmt(h)) \(fmt(h))"))
    }

    private func fmt(_ v: CGFloat) -> String {
        v == v.rounded() ? String(Int(v)) : String(Double(v))
    }

    @Test func firstFrameIsTheLaunchImage() {
        let (frame, stroke) = SplashLogic.brackets(at: 0, in: timeline, screen: screen)
        #expect(frame == SplashLogic.markFrame(screen: screen))
        #expect(stroke == SplashLogic.Mark.stroke)
        // Centred on the full screen, where iOS puts the launch image, and
        // with its outer edges on whole points.
        #expect(frame.rect.midX == screen.width / 2 && frame.rect.midY == screen.height / 2)
        let outer = frame.rect.insetBy(dx: -stroke / 2, dy: -stroke / 2)
        #expect(outer.minX == outer.minX.rounded() && outer.minY == outer.minY.rounded())
        #expect(outer.width == SplashLogic.Mark.imageSide)
        let first = SplashFrame.moving(at: 0, in: timeline, screen: screen)
        #expect(first.dotOpacity == 1 && first.dotRadius == SplashLogic.Mark.dotRadius)
        #expect(first.scene == 0 && first.credit == 0)
    }

    // MARK: - Hunt and lock

    @Test func huntBreathesOutward() {
        #expect(abs(side(at: timeline.lockStarts - 1e-6) - SplashLogic.Mark.side * 1.45) < 0.01)
        let values = stride(from: 0.0, to: timeline.lockStarts, by: 0.005).map(side(at:))
        #expect(zip(values, values.dropFirst()).allSatisfy { $0 <= $1 })
        #expect(close(SplashLogic.dotOpacity(at: timeline.lockStarts - 1e-9, in: timeline), 0.5, within: 1e-6))
    }

    @Test func lockSnapsInWithOneSmallOvershoot() {
        let tight = SplashLogic.Mark.side * SplashLogic.lockScale
        let wide = SplashLogic.Mark.side * 1.45
        #expect(abs(side(at: timeline.growStarts - 1e-9) - tight) < 0.01)
        let values = stride(from: timeline.lockStarts, to: timeline.growStarts, by: 0.001).map(side(at:))
        let smallest = values.min() ?? tight
        let overshoot = (tight - smallest) / (wide - tight)
        #expect(overshoot > 0.02 && overshoot < 0.08, "overshoot \(overshoot)")
        // One dip below and back: it crosses the target twice at most.
        let crossings = zip(values, values.dropFirst()).filter { ($0 - tight) * ($1 - tight) < 0 }.count
        #expect(crossings <= 2)
    }

    @Test func lockCurveStartsAndEndsOnTarget() {
        #expect(SplashLogic.lockCurve(0) == 0)
        #expect(close(SplashLogic.lockCurve(1), 1))
    }

    @Test func dotFlashesAndRingPulsesOnce() {
        let mid = timeline.lockStarts + timeline.lock / 2
        #expect(SplashLogic.dotScale(at: mid, in: timeline) > 1.3)
        #expect(SplashLogic.dotScale(at: timeline.growStarts, in: timeline) == 1)
        #expect(SplashLogic.ring(at: 0.05, in: timeline).opacity == 0)
        #expect(SplashLogic.ring(at: timeline.lockStarts + 0.01, in: timeline).opacity > 0.3)
        #expect(SplashLogic.ring(at: timeline.total, in: timeline).opacity == 0)
    }

    // MARK: - Into the scanner

    @Test func endsExactlyOnTheScannerBrackets() {
        for t in [timeline.total, timeline.total + 1] {
            let (frame, stroke) = SplashLogic.brackets(at: t, in: timeline, screen: screen)
            #expect(frame == ScanGeometry.lookingFrame(in: screen))
            #expect(stroke == 4)
        }
        // And the frame just before the end is already within a hair of it.
        let almost = SplashLogic.brackets(at: timeline.total - 0.001, in: timeline, screen: screen).frame.rect
        let target = ScanGeometry.lookingFrame(in: screen).rect
        #expect(abs(almost.width - target.width) < 0.5 && abs(almost.minY - target.minY) < 0.5)
    }

    @Test func growStartsFast() {
        let p = SplashLogic.growCurve.value(at: 0.25)
        #expect(p > 0.5)
    }

    @Test func sceneComesInOnlyDuringTheGrow() {
        #expect(SplashLogic.sceneOpacity(at: timeline.growStarts, in: timeline) == 0)
        #expect(close(SplashLogic.sceneOpacity(at: timeline.total, in: timeline), 1, within: 1e-6))
        #expect(SplashLogic.dotOpacity(at: timeline.total, in: timeline) == 0)
    }

    @Test func creditFadesInWithTheHuntAndOutBeforeTheControls() {
        #expect(SplashLogic.creditOpacity(at: 0, in: timeline) == 0)
        #expect(SplashLogic.creditOpacity(at: timeline.lockStarts, in: timeline) == 1)
        #expect(SplashLogic.creditOpacity(at: timeline.growStarts, in: timeline) == 1)
        #expect(SplashLogic.creditOpacity(at: timeline.total, in: timeline) == 0)
        // Gone before the scanner's controls are more than half in.
        let gone = timeline.growStarts + timeline.grow * 0.5
        #expect(SplashLogic.creditOpacity(at: gone, in: timeline) == 0)
        // Never pops: no jump bigger than a frame's worth.
        let values = stride(from: 0.0, through: timeline.total, by: 1.0 / 120).map { SplashLogic.creditOpacity(at: $0, in: timeline) }
        #expect(zip(values, values.dropFirst()).allSatisfy { abs($0 - $1) < 0.15 })
    }

    // MARK: - Reduce Motion

    @Test func stillHoldsThenCrossFades() {
        let still = SplashLogic.StillTimeline()
        let first = SplashFrame.still(at: 0, in: still, screen: screen)
        #expect(first.stillMark == SplashLogic.markFrame(screen: screen))
        #expect(first.stillMarkOpacity == 1 && first.scene == 0)
        let held = SplashFrame.still(at: still.hold, in: still, screen: screen)
        #expect(held.stillMark == first.stillMark && held.credit == 1)
        let last = SplashFrame.still(at: still.total, in: still, screen: screen)
        #expect(last.scene == 1 && last.stillMarkOpacity == 0 && last.credit < 1e-9)
        // The scanner's brackets never move: they only fade in where they live.
        #expect(first.brackets == ScanGeometry.lookingFrame(in: screen))
        #expect(last.brackets == first.brackets)
    }
}
