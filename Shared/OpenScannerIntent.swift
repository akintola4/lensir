//
//  OpenScannerIntent.swift
//  Lensir
//
//  Shared between the app AND the widget extension.
//
//  "Scan with Lensir": open the app on the live scanner. The Control Center
//  control runs it, and so do Siri, Spotlight, Shortcuts and the Action
//  Button. It has to be in both targets: the control lives in the extension,
//  but because the intent opens the app, iOS runs `perform` in the app.
//

import AppIntents

struct OpenScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan with Lensir"
    static let description = IntentDescription("Opens Lensir on the camera, ready to read a QR code or barcode.")
    /// Straight to the app, no confirmation.
    static let supportedModes: IntentModes = .foreground(.immediate)

    @MainActor
    func perform() async throws -> some IntentResult {
        LinkInbox.shared.receive(.scan)
        return .result()
    }
}
