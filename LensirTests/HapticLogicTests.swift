//
//  HapticLogicTests.swift
//  LensirTests
//
//  Which haptic plays for each event, and that the drawer only marks a
//  settle when a drag or tap lets go.
//

import SwiftUI
import Testing
@testable import Lensir

@Suite("Haptics")
struct HapticLogicTests {
    @Test func riskyCodePlaysTheWarning() {
        #expect(HapticLogic.feedback(for: .detected(risky: true), hapticsOn: true) == .warning)
    }

    @Test func safeCodeKeepsTheTick() {
        #expect(HapticLogic.feedback(for: .detected(risky: false), hapticsOn: true) == .impact(weight: .medium))
    }

    @Test func copyIsALightTick() {
        #expect(HapticLogic.feedback(for: .copied, hapticsOn: true) == .impact(weight: .light))
    }

    @Test(arguments: [(DrawerSnap.compact, DrawerSnap.expanded), (.expanded, .compact)])
    func landingOnANewDetentTicks(from: DrawerSnap, to: DrawerSnap) {
        #expect(HapticLogic.feedback(for: .drawerSettled(from: from, to: to), hapticsOn: true) == .selection)
    }

    @Test func dismissingIsSilent() {
        #expect(HapticLogic.feedback(for: .drawerSettled(from: .compact, to: .dismissed), hapticsOn: true) == nil)
        #expect(HapticLogic.feedback(for: .drawerSettled(from: .expanded, to: .dismissed), hapticsOn: true) == nil)
    }

    @Test func snappingBackToTheSameDetentIsSilent() {
        #expect(HapticLogic.feedback(for: .drawerSettled(from: .compact, to: .compact), hapticsOn: true) == nil)
    }

    @Test(arguments: [HapticEvent.detected(risky: true), .detected(risky: false), .copied,
                      .drawerSettled(from: .compact, to: .expanded)])
    func hapticsOffIsSilent(event: HapticEvent) {
        #expect(HapticLogic.feedback(for: event, hapticsOn: false) == nil)
    }
}

@Suite("Drawer settle")
@MainActor
struct DrawerSettleTests {
    /// The drawer's clock, moved by hand: no display link in tests.
    final class Clock {
        var now: CFTimeInterval = 100
    }

    let clock = Clock()
    let drawer: DrawerState

    init() {
        let clock = clock
        drawer = DrawerState(clock: { clock.now }, drivesItself: false)
        drawer.present(.compact, animated: false)
        drawer.measured(compact: 300, expanded: 700)
    }

    /// Runs the spring at 120 frames a second.
    func run(_ seconds: Double) {
        for _ in 0..<Int(seconds * 120) {
            clock.now += 1.0 / 120
            drawer.advance(to: clock.now)
        }
    }

    @Test func openingAndDraggingDoNotSettle() {
        drawer.dragChanged(-120)
        drawer.dragChanged(-240)
        #expect(drawer.lastSettle == nil)
    }

    @Test func releaseSettlesOnceWhenItLands() {
        drawer.dragChanged(-300)
        let target = drawer.dragEnded(velocity: -200)
        drawer.settle(to: target, velocity: 200, fromDrag: true)
        // Let go is not the beat; landing is.
        #expect(drawer.lastSettle == nil)
        run(0.1)
        #expect(drawer.lastSettle == nil)
        run(1)
        #expect(drawer.lastSettle == DrawerState.Settle(count: 1, from: .compact, to: .expanded))
        #expect(drawer.height == 700)
        #expect(!drawer.isMoving)
    }

    @Test func grabberTapSettles() {
        drawer.toggle()
        run(1)
        drawer.toggle()
        run(1)
        #expect(drawer.lastSettle == DrawerState.Settle(count: 2, from: .expanded, to: .compact))
    }

    @Test func caughtBeforeLandingDoesNotSettle() {
        drawer.toggle()
        run(0.08)
        drawer.hold()
        run(1)
        #expect(drawer.lastSettle == nil)
    }

    @Test func closingDoesNotSettle() {
        drawer.move(to: .dismissed)
        run(1)
        #expect(drawer.lastSettle == nil)
    }

    @Test func caughtWhileClosingStopsUnderTheFinger() {
        var closed = false
        drawer.move(to: .dismissed) { closed = true }
        run(0.08)
        let caught = drawer.height
        #expect(caught > 0 && caught < 300)
        drawer.hold()
        run(1)
        // Still where the finger stopped it, and the close never finished.
        #expect(drawer.height == caught)
        #expect(!closed)
        // Dragged back up from there, not from where it was headed.
        drawer.dragChanged(-50)
        #expect(abs(drawer.height - (caught + 50)) < 0.001)
        let target = drawer.dragEnded(velocity: 0)
        drawer.settle(to: target, fromDrag: true)
        run(1)
        #expect(drawer.height == 300)
        #expect(!closed)
    }

    @Test func heldThenLetGoCarriesOn() {
        drawer.move(to: .dismissed)
        run(0.15)
        drawer.hold()
        // Most of the way down already: letting go closes it.
        #expect(drawer.releaseHold() == .dismissed)
        #expect(drawer.releaseHold() == nil)
    }

    @Test func aDrawerAtRestCannotBeHeld() {
        drawer.hold()
        #expect(drawer.releaseHold() == nil)
        #expect(!drawer.isCatchable)
    }

    @Test func dimFollowsTheSpringEveryFrame() {
        drawer.toggle()
        for _ in 0..<20 {
            clock.now += 1.0 / 120
            drawer.advance(to: clock.now)
            let expected = DrawerLogic.dimOpacity(progress: DrawerLogic.progress(height: drawer.height, expanded: 700), base: 0.4)
            #expect(drawer.dim(base: 0.4) == expected)
        }
    }
}
