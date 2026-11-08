//
//  Brackets.swift
//  Lensir
//
//  Shared between the app AND the widget extension.
//
//  Lensir's four corner brackets: the scanner's viewfinder, the opening
//  animation, the launch mark, and the mark on the Lock Screen widget are all
//  this one shape.
//

import SwiftUI

nonisolated struct BracketFrame: Equatable, Sendable {
    var rect: CGRect
    var cornerRadius: CGFloat
    /// How far each bracket reaches from its corner, along each edge.
    var arm: CGFloat
}

typealias BracketFrameData = AnimatablePair<CGRect.AnimatableData, AnimatablePair<CGFloat, CGFloat>>

extension BracketFrame {
    nonisolated var animatableData: BracketFrameData {
        get { BracketFrameData(rect.animatableData, AnimatablePair(cornerRadius, arm)) }
        set {
            rect.animatableData = newValue.first
            cornerRadius = newValue.second.first
            arm = newValue.second.second
        }
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
