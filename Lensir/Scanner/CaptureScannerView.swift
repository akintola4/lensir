//
//  CaptureScannerView.swift
//  Lensir
//
//  The fallback when VisionKit's scanner isn't available on this phone: a
//  plain AVFoundation capture session reading QR codes and barcodes from
//  metadata output.
//

import AVFoundation
import SwiftUI

struct CaptureScannerView: UIViewRepresentable {
    var isScanning: Bool
    var onFound: (Detection) -> Void
    var onLost: () -> Void

    static var hasCamera: Bool { AVCaptureDevice.default(for: .video) != nil }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.setRunning(isScanning)
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: Coordinator) {
        coordinator.setRunning(false)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var parent: CaptureScannerView
        private let session = AVCaptureSession()
        private let queue = DispatchQueue(label: "lensir.capture")
        private weak var view: PreviewView?
        private var running = false

        init(parent: CaptureScannerView) {
            self.parent = parent
        }

        func configure(_ view: PreviewView) {
            self.view = view
            view.previewLayer.session = session
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.beginConfiguration()
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                let wanted: [AVMetadataObject.ObjectType] = [.qr, .microQR, .aztec, .dataMatrix, .pdf417, .ean13, .ean8, .upce, .code128, .code39, .itf14]
                output.metadataObjectTypes = wanted.filter(output.availableMetadataObjectTypes.contains)
            }
            session.commitConfiguration()
        }

        func setRunning(_ shouldRun: Bool) {
            guard shouldRun != running else { return }
            running = shouldRun
            // startRunning blocks while the camera spins up, so keep it off the main thread.
            nonisolated(unsafe) let session = session
            queue.async {
                if shouldRun { session.startRunning() } else { session.stopRunning() }
            }
        }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            MainActor.assumeIsolated {
                guard let code = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first(where: { $0.stringValue?.isEmpty == false }),
                      let raw = code.stringValue,
                      let transformed = view?.previewLayer.transformedMetadataObject(for: code) else {
                    parent.onLost()
                    return
                }
                parent.onFound(Detection(raw: raw, symbology: Self.name(code.type), bounds: transformed.bounds))
            }
        }

        private static func name(_ type: AVMetadataObject.ObjectType) -> String {
            switch type {
            case .qr, .microQR: "QR"
            case .aztec: "Aztec"
            case .dataMatrix: "Data Matrix"
            case .pdf417: "PDF417"
            case .ean13: "EAN-13"
            case .ean8: "EAN-8"
            case .upce: "UPC-E"
            case .code128: "Code 128"
            case .code39: "Code 39"
            case .itf14: "ITF-14"
            default: "Barcode"
            }
        }
    }
}
