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

    var body: some View {
        ZStack {
            DimShape(frame: frame)
                .fill(Palette.veil.opacity(dim), style: FillStyle(eoFill: true))
            if showsBrackets {
                BracketsShape(frame: frame)
                    .stroke(warning ? Palette.warning : Palette.ink, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    .opacity(bracketOpacity)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
