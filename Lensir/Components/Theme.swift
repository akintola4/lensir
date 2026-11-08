//
//  Theme.swift
//  Lensir
//
//  Lensir's few colours and its type. Ink (white on dark, black on light)
//  is the only accent. Green only ever means safe and red only ever means
//  warning. SF Mono carries the
//  brand: the wordmark, and every address, number and network name, where
//  a monospaced face keeps l, 1 and I (and O and 0) from passing for each
//  other. Everything else is SF Pro Rounded, as in the approved design.
//

import SwiftUI

/// A colour that follows the phone's appearance, and Increase Contrast
/// where it says. Every colour Lensir draws comes from one of these, so
/// light and dark are decided here and nowhere else.
nonisolated struct Swatch: Sendable, Equatable {
    var dark: UInt32
    var light: UInt32
    var darkAlpha: CGFloat = 1
    var lightAlpha: CGFloat = 1
    /// With Increase Contrast on, if it changes.
    var darkHigh: UInt32? = nil
    var lightHigh: UInt32? = nil
    var lightHighAlpha: CGFloat? = nil

    /// UIKit asks for this on whatever thread draws, so it touches nothing else.
    func resolve(style: UIUserInterfaceStyle, contrast: UIAccessibilityContrast) -> UIColor {
        let high = contrast == .high
        if style == .light {
            return Self.rgb(high ? (lightHigh ?? light) : light, alpha: high ? (lightHighAlpha ?? lightAlpha) : lightAlpha)
        }
        return Self.rgb(high ? (darkHigh ?? dark) : dark, alpha: darkAlpha)
    }

    var color: Color {
        let swatch = self
        return Color(uiColor: UIColor { swatch.resolve(style: $0.userInterfaceStyle, contrast: $0.accessibilityContrast) })
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Lensir is black and white. In dark mode white is the ink on black; in
/// light mode the same roles flip, black ink on white, the way Apple's own
/// apps do. Green only ever means safe and red only ever means warning.
enum Palette {
    nonisolated enum Swatches {
        /// Text, brackets, the wordmark, and the fill of the main buttons.
        static let ink = Swatch(dark: 0xFFFFFF, light: 0x000000)
        /// Text on an ink fill: the main buttons, the Make pill, the found pill.
        static let onInk = Swatch(dark: 0x000000, light: 0xFFFFFF)
        /// Behind the scanner and the opening animation.
        static let canvas = Swatch(dark: 0x000000, light: 0xFFFFFF)
        /// Behind History, Settings and the photo list's cards.
        static let grouped = Swatch(dark: 0x000000, light: 0xF2F2F7)
        /// Drawers and the cards in lists.
        static let sheet = Swatch(dark: 0x1C1C1E, light: 0xFFFFFF)
        /// Fields, secondary buttons and round buttons in a drawer.
        static let raised = Swatch(dark: 0x2C2C2E, light: 0xF2F2F7)
        /// An unselected kind in Make.
        static let chip = Swatch(dark: 0x2C2C2E, light: 0xE9E9EE)
        /// Round buttons over the camera.
        static let control = Swatch(dark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.16, lightAlpha: 0.92)
        /// Their edge, so a white button holds its shape over a bright scene.
        static let controlEdge = Swatch(dark: 0x000000, light: 0xE5E5EA, darkAlpha: 0)
        /// The drawer's top edge where it meets the camera.
        static let drawerEdge = Swatch(dark: 0x000000, light: 0xE5E5EA, darkAlpha: 0)
        /// A 1 pt edge just inside a white code tile, so it doesn't melt
        /// into a white card.
        static let tileEdge = Swatch(dark: 0x000000, light: 0x000000, darkAlpha: 0, lightAlpha: 0.1)
        /// Labels and the quiet parts of an address: 5.1:1 on white, and
        /// darker still with Increase Contrast.
        static let secondaryText = Swatch(dark: 0x8E8E93, light: 0x6E6E73, darkHigh: 0xAEAEB2, lightHigh: 0x3C3C43)
        static let checkText = Swatch(dark: 0xC7C7CC, light: 0x3C3C43, lightHigh: 0x1C1C1E)
        static let warningText = Swatch(dark: 0xE5E5EA, light: 0x1C1C1E)
        /// "Made by" on the opening.
        static let credit = Swatch(dark: 0xFFFFFF, light: 0x6E6E73)
        static let grabber = Swatch(dark: 0x636366, light: 0x6E6E73, lightAlpha: 0.5, lightHighAlpha: 1)
        /// The hint over the camera.
        static let hint = Swatch(dark: 0xF2F2F7, light: 0x000000)
        /// Keeps the wordmark and the hint readable over the scene: a soft
        /// shadow on dark, a faint white glow on light.
        static let glow = Swatch(dark: 0x000000, light: 0xFFFFFF, darkAlpha: 0.5, lightAlpha: 0.7)
        /// The veil around the brackets: black in dark, white in light, at
        /// the strength ScanGeometry and DrawerLogic ask for. Black is held
        /// back so dark mode dims exactly as it did.
        static let veil = Swatch(dark: 0x000000, light: 0xFFFFFF, darkAlpha: 0.84)
        static let safe = Swatch(dark: 0x34C759, light: 0x248A3D)
        static let warning = Swatch(dark: 0xFF6961, light: 0xD70015)
        /// The warning red on an ink fill (the found pill): #FF6961 is too
        /// light on white, #D70015 too dark on black.
        static let warningOnInk = Swatch(dark: 0xD70015, light: 0xFF6961)

        static let all: [String: Swatch] = [
            "ink": ink, "onInk": onInk, "canvas": canvas, "grouped": grouped, "sheet": sheet, "raised": raised,
            "chip": chip, "control": control, "controlEdge": controlEdge, "drawerEdge": drawerEdge, "tileEdge": tileEdge,
            "secondaryText": secondaryText, "checkText": checkText, "warningText": warningText, "credit": credit,
            "grabber": grabber, "hint": hint, "glow": glow, "veil": veil, "safe": safe, "warning": warning,
            "warningOnInk": warningOnInk,
        ]
    }

    static let ink = Swatches.ink.color
    static let onInk = Swatches.onInk.color
    static let canvas = Swatches.canvas.color
    static let grouped = Swatches.grouped.color
    static let sheet = Swatches.sheet.color
    static let raised = Swatches.raised.color
    static let chip = Swatches.chip.color
    static let control = Swatches.control.color
    static let controlEdge = Swatches.controlEdge.color
    static let drawerEdge = Swatches.drawerEdge.color
    static let tileEdge = Swatches.tileEdge.color
    static let secondaryText = Swatches.secondaryText.color
    static let checkText = Swatches.checkText.color
    static let warningText = Swatches.warningText.color
    static let credit = Swatches.credit.color
    static let grabber = Swatches.grabber.color
    static let hint = Swatches.hint.color
    static let glow = Swatches.glow.color
    static let veil = Swatches.veil.color
    static let safe = Swatches.safe.color
    static let warning = Swatches.warning.color
    static let warningOnInk = Swatches.warningOnInk.color
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
    /// Text fields and the Security menu: 10 to the button's 12, as drawn.
    static let fieldRadius: CGFloat = 12
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
    /// Ink with the icon cut out: the torch while it's on.
    var filled = false
    var background: Color = Palette.control

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: diameter > 48 ? 21 : 17, weight: .semibold))
            .foregroundStyle(filled ? Palette.onInk : Palette.ink)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(filled ? Palette.ink : background))
            .overlay(Circle().strokeBorder(filled || background != Palette.control ? .clear : Palette.controlEdge, lineWidth: 0.8))
            .contentShape(Circle())
    }
}

extension View {
    /// The full-width main button in a sheet, filled with ink.
    func primaryButtonStyle() -> some View {
        font(Typeface.primaryButton)
            .foregroundStyle(Palette.onInk)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous).fill(Palette.ink))
            .contentShape(RoundedRectangle(cornerRadius: Metrics.buttonRadius, style: .continuous))
    }
}
