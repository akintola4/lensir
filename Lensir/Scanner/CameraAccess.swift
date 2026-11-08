//
//  CameraAccess.swift
//  Lensir
//
//  Asks for the camera, picks VisionKit or the AVFoundation fallback, and
//  switches the torch.
//

import AVFoundation
import UIKit

enum CameraAccess {
    /// Which camera the scanner should run, asking for permission the first time.
    static func resolve() async -> ScannerModel.Camera {
        if LaunchOptions.demo != nil { return .demo }
        if LaunchOptions.cameraDenied { return .denied }
        if LaunchOptions.noCamera { return .unavailable }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { return .denied }
        case .denied, .restricted:
            return .denied
        default:
            break
        }
        if DataScannerView.isAvailable { return .dataScanner }
        if CaptureScannerView.hasCamera { return .capture }
        return .unavailable
    }

    static var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    /// Turns the torch on or off. Returns whether it ended up on.
    @discardableResult
    static func setTorch(_ on: Bool) -> Bool {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return false }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
            return on
        } catch {
            return false
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
