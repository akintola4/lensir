//
//  ScannerFocus.swift
//  Lensir
//
//  The line over the bottom buttons, and where VoiceOver goes when the
//  result drawer closes: back to that line, or to Scan a photo when there's
//  no camera and so no line.
//

nonisolated enum ScannerFocus: Hashable, Sendable {
    case hint
    case photoButton
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
}
