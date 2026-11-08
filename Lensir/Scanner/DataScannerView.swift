//
//  DataScannerView.swift
//  Lensir
//
//  VisionKit's live scanner, with its own highlighting and guidance turned
//  off so Lensir's brackets are the only thing drawn over the camera.
//

import SwiftUI
import Vision
import VisionKit

struct DataScannerView: UIViewControllerRepresentable {
    var isScanning: Bool
    var onFound: (Detection) -> Void
    var onLost: () -> Void

    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: Symbology.all)],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        scanner.view.backgroundColor = .black
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if isScanning, !scanner.isScanning {
            try? scanner.startScanning()
        } else if !isScanning, scanner.isScanning {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerView

        init(parent: DataScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            report(allItems)
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                guard case .barcode(let barcode) = item, let raw = barcode.payloadStringValue, !raw.isEmpty else { continue }
                let corners = [barcode.bounds.topLeft, barcode.bounds.topRight, barcode.bounds.bottomLeft, barcode.bounds.bottomRight]
                let xs = corners.map(\.x), ys = corners.map(\.y)
                let bounds = CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
                parent.onFound(Detection(raw: raw, symbology: Symbology.name(barcode.observation.symbology), bounds: bounds))
                return
            }
            parent.onLost()
        }
    }
}

nonisolated enum Symbology {
    /// QR first, then the 2D codes, then the barcodes on products and parcels.
    static let all: [VNBarcodeSymbology] = [.qr, .microQR, .aztec, .dataMatrix, .pdf417, .ean13, .ean8, .upce, .code128, .code39, .itf14]

    static func name(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr, .microQR: "QR"
        case .aztec: "Aztec"
        case .dataMatrix: "Data Matrix"
        case .pdf417, .microPDF417: "PDF417"
        case .ean13: "EAN-13"
        case .ean8: "EAN-8"
        case .upce: "UPC-E"
        case .code128: "Code 128"
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: "Code 39"
        case .itf14: "ITF-14"
        default: "Barcode"
        }
    }
}
