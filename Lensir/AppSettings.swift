//
//  AppSettings.swift
//  Lensir
//
//  Haptics, and whether a found code opens its drawer by itself.
//

import SwiftUI

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var haptics: Bool { didSet { defaults.set(haptics, forKey: Keys.haptics) } }
    /// "Open results right away". Off unless you turn it on.
    var autoOpen: Bool { didSet { defaults.set(autoOpen, forKey: Keys.autoOpen) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        // -LensirAutoOpen turns it on for this run only, for UI tests.
        autoOpen = LaunchOptions.autoOpen || defaults.bool(forKey: Keys.autoOpen)
    }

    private enum Keys {
        static let haptics = "haptics"
        static let autoOpen = "autoOpenResults"
    }
}
