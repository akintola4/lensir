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
                .fill(Color.black.opacity(dim), style: FillStyle(eoFill: true))
            if showsBrackets {
                BracketsShape(frame: frame)
                    .stroke(warning ? Palette.warning : .white, style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round))
                    .opacity(bracketOpacity)
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private typealias FrameData = AnimatablePair<CGRect.AnimatableData, AnimatablePair<CGFloat, CGFloat>>

private extension BracketFrame {
    nonisolated var animatableData: FrameData {
        get { FrameData(rect.animatableData, AnimatablePair(cornerRadius, arm)) }
        set {
            rect.animatableData = newValue.first
            cornerRadius = newValue.second.first
            arm = newValue.second.second
        }
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

/// Four corners: an arc with a straight arm running off each end.
nonisolated struct BracketsShape: Shape {
    var frame: BracketFrame

    var animatableData: AnimatablePair<CGRect.AnimatableData, AnimatablePair<CGFloat, CGFloat>> {
        get { frame.animatableData }
        set { frame.animatableData = newValue }
    }

    func path(in _: CGRect) -> Path {
        let r = frame.rect
        let radius = min(frame.cornerRadius, r.width / 2, r.height / 2)
        let arm = max(frame.arm, radius)
        var path = Path()
        // Top left
        path.move(to: CGPoint(x: r.minX, y: r.minY + arm))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        path.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
        // Top right
        path.move(to: CGPoint(x: r.maxX - arm, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        path.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))
        // Bottom right
        path.move(to: CGPoint(x: r.maxX, y: r.maxY - arm))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        path.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))
        // Bottom left
        path.move(to: CGPoint(x: r.minX + arm, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        path.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return path
    }
}
