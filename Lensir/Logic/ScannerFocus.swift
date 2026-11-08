//
//  ScannerFocus.swift
//  Lensir
//
//  The line over the bottom buttons, and where VoiceOver goes when a
//  drawer closes. After a result: back to that line, or to Scan a photo
//  when there's no camera and so no line. After making a code: back to
//  Make, the button that opened it.
//

nonisolated enum ScannerFocus: Hashable, Sendable {
    case hint
    case photoButton
    case makeButton
}

/// Which drawer is up over the scanner.
nonisolated enum OpenDrawer: Equatable, Sendable {
    case result, make
}

nonisolated enum ScannerFocusLogic {
    /// A notice like "No code in that photo" wins; otherwise the prompt,
    /// while the camera runs with no code in view.
    static func hintText(notice: String?, cameraIsLive: Bool, codeInView: Bool) -> String? {
        notice ?? (cameraIsLive && !codeInView ? "Point at a QR code" : nil)
    }

    static func afterDrawerCloses(hint: String?) -> ScannerFocus {
        hint == nil ? .photoButton : .hint
    }

    static func afterClosing(_ drawer: OpenDrawer, hint: String?) -> ScannerFocus {
        switch drawer {
        case .result: afterDrawerCloses(hint: hint)
        case .make: .makeButton
        }
    }
}
