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
    func openDrawer() -> DrawerState {
        let drawer = DrawerState()
        drawer.present(.compact, animated: false)
        drawer.measured(compact: 300, expanded: 700)
        return drawer
    }

    @Test func openingAndDraggingDoNotSettle() {
        let drawer = openDrawer()
        drawer.dragChanged(-120)
        drawer.dragChanged(-240)
        #expect(drawer.lastSettle == nil)
    }

    @Test func releaseSettlesOnceWithTheTarget() {
        let drawer = openDrawer()
        drawer.dragChanged(-300)
        let target = drawer.dragEnded(velocity: -200)
        drawer.settle(to: target, velocity: 200)
        #expect(drawer.lastSettle == DrawerState.Settle(count: 1, from: .compact, to: .expanded))
    }

    @Test func grabberTapSettles() {
        let drawer = openDrawer()
        drawer.toggle()
        drawer.toggle()
        #expect(drawer.lastSettle == DrawerState.Settle(count: 2, from: .expanded, to: .compact))
    }

    @Test func closingDoesNotSettle() {
        let drawer = openDrawer()
        drawer.move(to: .dismissed)
        #expect(drawer.lastSettle == nil)
    }
}
