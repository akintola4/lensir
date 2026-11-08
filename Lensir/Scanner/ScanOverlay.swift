//
//  ScanOverlay.swift
//  Lensir
//
//  Four corner brackets and the dim around them. No box: just the corners,
//  like Apple's Camera. Both shapes animate their rectangle, radius and
//  arm length together, so the brackets can snap from the idle window onto
//  a code in one move.
//

import SwiftUI

struct ScanOverlay: View {
    var frame: BracketFrame
    var dim: Double
    var warning: Bool
    var showsBrackets: Bool
    /// 4 pt; the opening animation starts them at the launch mark's 5.
    var stroke: CGFloat = SplashLogic.scannerStroke
    var bracketOpacity: Double = 1
    /// Make or the photo list is up: there's nothing to aim at, so the
    /// window takes the veil too and the brackets step back.
    var fillsWindow = false
    /// Light, while looking: wash the window white. Off once the brackets
    /// are on a code, so the code itself reads crisp.
    var washesWindow = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // With nothing to aim at, the hole in the veil closes to a point,
        // so the veil is one even sheet with no seam where the window was.
        let hole = fillsWindow
            ? BracketFrame(rect: CGRect(x: frame.rect.midX, y: frame.rect.midY, width: 0, height: 0), cornerRadius: 0, arm: 0)
            : frame
        ZStack {
            DimShape(frame: hole)
                .fill(Palette.veil.opacity(dim), style: FillStyle(eoFill: true))
            // Light: a white wash over the window, a little stronger than
            // the grey veil around it, so the window is always the lightest
            // part of the screen. Dark: nothing, the camera shows clear.
            WindowShape(frame: hole)
                .fill(Palette.lensWash.opacity(washesWindow ? dim : 0))
            if showsBrackets {
                ZStack {
                    // Light: a white rim, so black brackets hold over a dark scene.
                    BracketsShape(frame: frame)
                        .stroke(Palette.bracketHalo, style: StrokeStyle(lineWidth: stroke + Self.haloWidth * 2, lineCap: .round, lineJoin: .round))
                    BracketsShape(frame: frame)
                        .stroke(warning ? Palette.warning : Palette.ink, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                }
                .opacity(fillsWindow ? 0 : bracketOpacity)
                .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: fillsWindow)
        .animation(Motion.fade, value: washesWindow)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The white rim's width each side of a light-mode bracket.
    static let haloWidth: CGFloat = 1.5
}

/// The window the brackets frame.
nonisolated struct WindowShape: Shape {
    var frame: BracketFrame

    var animatableData: AnimatablePair<CGRect.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { frame.animatableData }
        set { frame.animatableData = newValue }
    }

    func path(in _: CGRect) -> Path {
        Path(roundedRect: frame.rect, cornerSize: CGSize(width: frame.cornerRadius, height: frame.cornerRadius), style: .circular)
    }
}

/// The whole screen with a rounded hole where the brackets are.
nonisolated struct DimShape: Shape {
    var frame: BracketFrame

    var animatableData: AnimatablePair<CGRect.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { frame.animatableData }
        set { frame.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -200, dy: -200))
        path.addRoundedRect(in: frame.rect, cornerSize: CGSize(width: frame.cornerRadius, height: frame.cornerRadius), style: .circular)
        return path
    }
}
