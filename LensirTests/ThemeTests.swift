//
//  ThemeTests.swift
//  LensirTests
//
//  Light and dark: every colour resolves to the value it should in each
//  appearance, dark mode is exactly what it was before light existed, and
//  the launch screen's colour follows the phone too.
//

import Testing
import UIKit
@testable import Lensir

@Suite("Light and dark")
struct ThemeTests {
    /// The colour as #RRGGBB and its alpha, to compare by eye.
    private func hex(_ color: UIColor) -> (String, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let hex = String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        return (hex, (Double(a) * 100).rounded() / 100)
    }

    private func resolve(_ name: String, _ style: UIUserInterfaceStyle, high: Bool = false) throws -> (String, Double) {
        let swatch = try #require(Palette.Swatches.all[name])
        return hex(swatch.resolve(style: style, contrast: high ? .high : .normal))
    }

    /// name, dark, light. Alpha 1 unless it says.
    static let expected: [(String, String, String)] = [
        ("ink", "#FFFFFF", "#000000"),
        ("onInk", "#000000", "#FFFFFF"),
        ("canvas", "#000000", "#FFFFFF"),
        ("grouped", "#000000", "#F2F2F7"),
        ("sheet", "#1C1C1E", "#FFFFFF"),
        ("raised", "#2C2C2E", "#F2F2F7"),
        ("chip", "#2C2C2E", "#E9E9EE"),
        ("secondaryText", "#A1A1A6", "#6E6E73"),
        ("checkText", "#C7C7CC", "#3C3C43"),
        ("warningText", "#E5E5EA", "#1C1C1E"),
        ("credit", "#FFFFFF", "#6E6E73"),
        ("grabber", "#636366", "#6E6E73"),
        ("hint", "#F2F2F7", "#000000"),
        ("safe", "#34C759", "#248A3D"),
        ("warning", "#FF6961", "#D70015"),
        ("warningOnInk", "#D70015", "#FF6961"),
        ("controlEdge", "#000000", "#000000"),
        ("drawerEdge", "#000000", "#000000"),
        ("veil", "#000000", "#E5E5EA"),
        ("glow", "#000000", "#FFFFFF"),
        ("backdrop", "#000000", "#000000"),
        ("separator", "#38383A", "#000000"),
        ("disabledFill", "#3A3A3C", "#E5E5EA"),
        ("warningLabel", "#FF8780", "#D70015"),
        ("paper", "#FFFFFF", "#FFFFFF"),
        ("paperInk", "#000000", "#000000"),
        ("paperQuiet", "#6E6E73", "#6E6E73"),
        ("paperButton", "#E5E5EA", "#E5E5EA"),
        ("failChip", "#452A2A", "#FBE6E8"),
    ]

    @Test(arguments: expected)
    func tokenResolvesPerAppearance(token: (String, String, String)) throws {
        #expect(try resolve(token.0, .dark).0 == token.1)
        #expect(try resolve(token.0, .light).0 == token.2)
    }

    @Test func everyTokenIsCovered() {
        let tested = Set(Self.expected.map(\.0))
        #expect(Set(Palette.Swatches.all.keys).subtracting(tested) == ["control", "tileEdge", "controlShadow", "lensWash", "bracketHalo"])
    }

    @Test func translucentTokens() throws {
        #expect(try resolve("control", .dark) == ("#FFFFFF", 0.16))
        #expect(try resolve("control", .light) == ("#FFFFFF", 0.92))
        #expect(try resolve("grabber", .light).1 == 0.5)
        #expect(try resolve("veil", .dark).1 == 0.84)
        #expect(try resolve("veil", .light).1 == 1)
        // Edges only exist in light; dark mode looks exactly as it did.
        #expect(try resolve("controlEdge", .dark).1 == 0)
        #expect(try resolve("drawerEdge", .dark).1 == 0)
        #expect(try resolve("tileEdge", .dark).1 == 0)
        #expect(try resolve("tileEdge", .light) == ("#000000", 0.1))
        #expect(try resolve("controlShadow", .dark).1 == 0)
        #expect(try resolve("lensWash", .dark).1 == 0)
        #expect(try resolve("bracketHalo", .dark).1 == 0)
        // Light: hairlines of black that darken whatever they sit on.
        #expect(try resolve("controlEdge", .light) == ("#000000", 0.12))
        #expect(try resolve("drawerEdge", .light) == ("#000000", 0.08))
        #expect(try resolve("separator", .light) == ("#000000", 0.1))
        #expect(try resolve("bracketHalo", .light) == ("#FFFFFF", 1))
    }

    /// Light's veil is a spotlight like dark's: wherever the brackets wait,
    /// the window is at least as light as the veil around it, over any
    /// scene from black to white and at every strength the veil takes.
    @Test func lightWindowIsNeverDarkerThanItsVeil() {
        let veil = Palette.Swatches.veil, wash = Palette.Swatches.lensWash
        let channels = [(veil.light >> 16) & 0xFF, (veil.light >> 8) & 0xFF, veil.light & 0xFF].map { Double($0) }
        for dim in [ScanGeometry.dimOpacity(found: false), ScanGeometry.dimOpacity(found: true), DrawerLogic.dimMax] {
            let a = dim * Double(veil.lightAlpha), w = dim * Double(wash.lightAlpha)
            for scene in stride(from: 0.0, through: 255, by: 1) {
                for g in channels {
                    let surround = scene * (1 - a) + g * a
                    let window = scene * (1 - w) + 255 * w
                    #expect(window >= surround - 1e-9)
                }
            }
        }
    }

    @Test func increaseContrastDarkensGreyOnLight() throws {
        #expect(try resolve("secondaryText", .light, high: true).0 == "#3C3C43")
        #expect(try resolve("secondaryText", .dark, high: true).0 == "#AEAEB2")
        #expect(try resolve("checkText", .light, high: true).0 == "#1C1C1E")
        #expect(try resolve("grabber", .light, high: true) == ("#6E6E73", 1))
        #expect(try resolve("failChip", .light, high: true).0 == "#F5D0D4")
        #expect(try resolve("failChip", .dark, high: true).0 == "#5A3030")
    }

    /// The veil dims dark mode exactly as before: 52% looking, 55% found,
    /// 70% under an open drawer; and light gets the 62% grey veil.
    @Test func veilKeepsDarkModeAndGivesLightItsVeil() {
        let black = 0.84
        #expect(abs(ScanGeometry.dimOpacity(found: false) * black - 0.52) < 0.002)
        #expect(abs(ScanGeometry.dimOpacity(found: true) * black - 0.55) < 0.002)
        #expect(abs(DrawerLogic.dimMax * black - 0.7) < 0.002)
        #expect(ScanGeometry.dimOpacity(found: false) == 0.62)
    }

    @Test(arguments: ["LaunchBackground", "AccentColor"])
    func assetColourHasBothAppearances(name: String) throws {
        let color = try #require(UIColor(named: name, in: Bundle(for: DrawerState.self), compatibleWith: nil))
        let dark = hex(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))).0
        let light = hex(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))).0
        #expect(dark == "#000000" || name == "AccentColor")
        #expect(light == (name == "AccentColor" ? "#000000" : "#FFFFFF"))
        #expect(dark != light)
    }

    @Test func launchMarkHasBothAppearances() throws {
        let image = try #require(UIImage(named: "LaunchMark", in: Bundle(for: DrawerState.self), compatibleWith: nil))
        let assets = try #require(image.imageAsset)
        let dark = assets.image(with: UITraitCollection(userInterfaceStyle: .dark))
        let light = assets.image(with: UITraitCollection(userInterfaceStyle: .light))
        #expect(dark.pngData() != light.pngData())
    }
}
