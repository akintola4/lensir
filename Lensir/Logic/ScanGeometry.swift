//
//  ScanGeometry.swift
//  Lensir
//
//  Where the brackets sit and where the pill goes. Plain functions of the
//  screen size and the code's bounds, so they're tested without a camera.
//

import CoreGraphics

nonisolated enum ScanGeometry {
    /// The idle window: a square at about two-thirds of the width, a little
    /// above the middle, where a thumb-held phone naturally points.
    static func lookingFrame(in size: CGSize) -> BracketFrame {
        let side = min((size.width * 0.68).rounded(), 280)
        let rect = CGRect(x: ((size.width - side) / 2).rounded(), y: (size.height * 0.42 - side / 2).rounded(),
                          width: side, height: side)
        return BracketFrame(rect: rect, cornerRadius: 20, arm: 42)
    }

    /// Close around a found code, in its quiet zone, as drawn: 20 pt out
    /// from the modules. Tiny codes still get brackets you can see.
    static func foundFrame(around code: CGRect, in size: CGSize) -> BracketFrame {
        var rect = code.insetBy(dx: -20, dy: -20)
        let minimum: CGFloat = 88
        if rect.width < minimum { rect = rect.insetBy(dx: (rect.width - minimum) / 2, dy: 0) }
        if rect.height < minimum { rect = rect.insetBy(dx: 0, dy: (rect.height - minimum) / 2) }
        let arm = min(30, rect.width / 3, rect.height / 3)
        return BracketFrame(rect: rect.integral, cornerRadius: 12, arm: arm)
    }

    /// Centre of the pill: just under the code, centred on it, kept inside the
    /// screen. If there's no room underneath, it goes above.
    static func pillCenter(below frame: CGRect, pillSize: CGSize, in size: CGSize,
                           margin: CGFloat = 16, bottomReserve: CGFloat = 140, gap: CGFloat = 16) -> CGPoint {
        let half = pillSize.width / 2
        let x = min(max(frame.midX, margin + half), size.width - margin - half)
        var y = frame.maxY + gap + pillSize.height / 2
        if y + pillSize.height / 2 > size.height - bottomReserve {
            y = frame.minY - gap - pillSize.height / 2
        }
        y = max(y, margin + pillSize.height / 2)
        return CGPoint(x: x.rounded(), y: y.rounded())
    }

    /// How dark the camera gets outside the brackets. The result drawer
    /// deepens it further as it rises (DrawerLogic.dimOpacity).
    static func dimOpacity(found: Bool) -> Double {
        found ? 0.55 : 0.52
    }
}
