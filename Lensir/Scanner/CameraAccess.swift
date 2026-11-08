//
//  CameraAccess.swift
//  Lensir
//
//  Asks for the camera, picks VisionKit or the AVFoundation fallback, and
//  switches the torch.
//

import AVFoundation
import UIKit

/// Which camera device the torch is switched on, in order of preference.
nonisolated enum TorchLogic {
    static func deviceTypes(visionKit: Bool) -> [AVCaptureDevice.DeviceType] {
        visionKit
            // VisionKit runs the most capable virtual camera on the back.
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            // The fallback's session runs AVCaptureDevice.default(for: .video).
            : [.builtInWideAngleCamera]
    }
}

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
    ///
    /// The torch has to be switched on the device the scanner's session is
    /// running. Locking any other one, even the same physical lens through a
    /// different device, makes iOS treat it as a second app taking the camera:
    /// the session is interrupted (videoDeviceInUseByAnotherClient) and the
    /// picture freezes until the torch goes off. VisionKit runs the most
    /// capable virtual camera (triple on an iPhone 12 Pro); the fallback
    /// scanner runs the default one.
    @discardableResult
    static func setTorch(_ on: Bool, for camera: ScannerModel.Camera) -> Bool {
        guard let device = torchDevice(for: camera), device.hasTorch else { return false }
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

    private static func torchDevice(for camera: ScannerModel.Camera) -> AVCaptureDevice? {
        let types = TorchLogic.deviceTypes(visionKit: camera == .dataScanner)
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .back)
            .devices
            .min { types.firstIndex(of: $0.deviceType) ?? .max < types.firstIndex(of: $1.deviceType) ?? .max }
    }

    /// Whether an interruption means the torch took the camera away from the
    /// scanner, so the torch should go off rather than leave a frozen picture.
    static func torchCausedInterruption(_ note: Notification) -> Bool {
        guard let raw = note.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int else { return false }
        return AVCaptureSession.InterruptionReason(rawValue: raw) == .videoDeviceInUseByAnotherClient
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
