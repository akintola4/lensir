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
        ("secondaryText", "#8E8E93", "#6E6E73"),
        ("checkText", "#C7C7CC", "#3C3C43"),
        ("warningText", "#E5E5EA", "#1C1C1E"),
        ("credit", "#FFFFFF", "#6E6E73"),
        ("grabber", "#636366", "#6E6E73"),
        ("hint", "#F2F2F7", "#000000"),
        ("safe", "#34C759", "#248A3D"),
        ("warning", "#FF6961", "#D70015"),
        ("warningOnInk", "#D70015", "#FF6961"),
        ("controlEdge", "#000000", "#E5E5EA"),
        ("drawerEdge", "#000000", "#E5E5EA"),
        ("veil", "#000000", "#FFFFFF"),
        ("glow", "#000000", "#FFFFFF"),
    ]

    @Test(arguments: expected)
    func tokenResolvesPerAppearance(token: (String, String, String)) throws {
        #expect(try resolve(token.0, .dark).0 == token.1)
        #expect(try resolve(token.0, .light).0 == token.2)
    }

    @Test func everyTokenIsCovered() {
        let tested = Set(Self.expected.map(\.0))
        #expect(Set(Palette.Swatches.all.keys).subtracting(tested) == ["control", "tileEdge"])
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
    }

    @Test func increaseContrastDarkensGreyOnLight() throws {
        #expect(try resolve("secondaryText", .light, high: true).0 == "#3C3C43")
        #expect(try resolve("secondaryText", .dark, high: true).0 == "#AEAEB2")
        #expect(try resolve("checkText", .light, high: true).0 == "#1C1C1E")
        #expect(try resolve("grabber", .light, high: true) == ("#6E6E73", 1))
    }

    /// The veil dims dark mode exactly as before: 52% looking, 55% found,
    /// 70% under an open drawer; and light gets the 62% white veil.
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
