//
//  Theme.swift
//  Lensir
//
//  Lensir's few colours and its type. White is the only accent. Green only
//  ever means safe and red only ever means warning. SF Mono carries the
//  brand: the wordmark, and every address, number and network name, where
//  a monospaced face keeps l, 1 and I (and O and 0) from passing for each
//  other. Everything else is SF Pro Rounded, as in the approved design.
//

import SwiftUI

enum Palette {
    static let sheet = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let raised = Color(red: 0x2C / 255, green: 0x2C / 255, blue: 0x2E / 255)
    static let control = Color.white.opacity(0.16)
    /// Labels and the quiet parts of an address. With Increase Contrast on
    /// it brightens from #8E8E93 to #AEAEB2.
    static let secondaryText = Color(UIColor { secondaryText(contrast: $0.accessibilityContrast) })
    static let checkText = Color(red: 0xC7 / 255, green: 0xC7 / 255, blue: 0xCC / 255)
    static let warningText = Color(red: 0xE5 / 255, green: 0xE5 / 255, blue: 0xEA / 255)
    static let grabber = Color(red: 0x63 / 255, green: 0x63 / 255, blue: 0x66 / 255)
    static let hint = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF7 / 255)
    static let safe = Color(red: 0x34 / 255, green: 0xC7 / 255, blue: 0x59 / 255)
    static let warning = Color(red: 0xFF / 255, green: 0x69 / 255, blue: 0x61 / 255)
    /// The warning red on white (the found pill): #FF6961 is too light there.
    static let warningOnLight = Color(red: 0xD7 / 255, green: 0x00 / 255, blue: 0x15 / 255)

    /// UIKit asks for this on whatever thread draws, so it touches nothing else.
    nonisolated static func secondaryText(contrast: UIAccessibilityContrast) -> UIColor {
        contrast == .high
            ? UIColor(red: 0xAE / 255, green: 0xAE / 255, blue: 0xB2 / 255, alpha: 1)
            : UIColor(red: 0x8E / 255, green: 0x8E / 255, blue: 0x93 / 255, alpha: 1)
    }
}

enum Typeface {
    /// "Lensir", SF Mono Bold 17.
    static let wordmark = Font.system(.body, design: .monospaced).weight(.bold)
    /// A domain, network name or number at the top of the sheet: SF Mono Semibold 17.
    static let monoTitle = Font.system(.body, design: .monospaced).weight(.semibold)
    static let title = Font.system(.body, design: .rounded).weight(.semibold)
    /// The full address: SF Mono 12.
    static let address = Font.system(.caption, design: .monospaced)
    static let addressBold = Font.system(.caption, design: .monospaced).weight(.bold)
    static let kindLabel = Font.system(.caption, design: .rounded).weight(.semibold)
    static let check = Font.system(.footnote, design: .rounded).weight(.semibold)
    static let primaryButton = Font.system(.callout, design: .rounded).weight(.bold)
    static let secondaryButton = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let hint = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let pill = Font.system(.footnote, design: .monospaced).weight(.semibold)
    static let sectionHeader = Font.system(.subheadline, design: .rounded).weight(.bold)
    static let body = Font.system(.subheadline, design: .rounded)
    static let monoBody = Font.system(.subheadline, design: .monospaced)
}

enum Metrics {
    /// Inset of the controls and the sheet from the screen edges.
    static let edge: CGFloat = 14
    /// The drawer's top corners. Its other edges are flush with the screen.
    static let drawerRadius: CGFloat = 28
    static let sheetPadding: CGFloat = 16
    /// 30 − 16, as approved: the button kept its radius when the floating
    /// card became the edge drawer.
    static let buttonRadius: CGFloat = 14
}

enum Motion {
    /// Brackets snapping onto a found code: fast, strong ease-out, no bounce.
    static let snap = Animation.spring(duration: 0.22, bounce: 0)
    /// Brackets following a code that's moving in the frame.
    static let track = Animation.spring(duration: 0.12, bounce: 0)
    static let fade = Animation.easeOut(duration: 0.2)
    static let exit = Animation.easeIn(duration: 0.16)
}

/// Every tappable thing shrinks to 0.96 while pressed. With Reduce Motion
/// it dims instead.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A round, translucent button over the camera: 44 pt at the top, 52 pt at
/// the bottom.
struct CircleIcon: View {
    var systemName: String
    var diameter: CGFloat = 44
    /// White with a black icon: the torch while it's on.
    var filled = false
    var background: Color = Palette.control

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: diameter > 48 ? 21 : 17, weight: .semibold))
            .foregroundStyle(filled ? Color.black : Color.white)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(filled ? Color.white : background))
            .contentShape(Circle())
    }
}

extension View {
    /// The white, full-width main button in a sheet.
    func primaryButtonStyle() -> some View {
        font(Typeface.primaryButton)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(.white))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
    }
}
