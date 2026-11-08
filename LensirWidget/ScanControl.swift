//
//  ScanControl.swift
//  LensirWidget
//
//  "Scan with Lensir" as a control. One control works in all three places
//  iOS offers them: Control Center, the two Lock Screen buttons, and the
//  Action Button (Settings > Action Button > Controls).
//

import AppIntents
import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {
    static let kind = "LensirScanControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenScannerIntent()) {
                // The brackets and lens dot, drawn as a custom SF Symbol so
                // it takes the control's weight and tint like a system one.
                Label("Scan with Lensir", image: "lensir.viewfinder")
            }
        }
        .displayName("Scan with Lensir")
        .description("Opens Lensir on the camera, ready to read a code.")
    }
}
