//
//  LensirWidgetBundle.swift
//  LensirWidget
//
//  Two ways to the scanner from outside the app: a control for Control
//  Center, the Lock Screen's bottom corners and the Action Button, and a
//  Lock Screen widget.
//

import SwiftUI
import WidgetKit

@main
struct LensirWidgetBundle: WidgetBundle {
    var body: some Widget {
        ScanControl()
        ScanWidget()
    }
}
