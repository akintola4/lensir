//
//  AppSettings.swift
//  Lensir
//
//  The one setting: a light tap when a code is found.
//

import SwiftUI

@Observable
final class AppSettings {
    private let defaults: UserDefaults

    var haptics: Bool { didSet { defaults.set(haptics, forKey: Keys.haptics) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
    }

    private enum Keys {
        static let haptics = "haptics"
    }
}
