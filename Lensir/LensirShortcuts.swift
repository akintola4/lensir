//
//  LensirShortcuts.swift
//  Lensir
//
//  Siri, Spotlight and the Shortcuts app get "Scan with Lensir" without any
//  setup, and so does the Action Button's Shortcut option.
//

import AppIntents

struct LensirShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: [
                "Scan with \(.applicationName)",
                "Scan a code with \(.applicationName)",
                "Check a QR code with \(.applicationName)",
                "Open \(.applicationName) scanner",
            ],
            shortTitle: "Scan a Code",
            systemImageName: "viewfinder"
        )
    }
}
