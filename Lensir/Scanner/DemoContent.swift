//
//  DemoContent.swift
//  Lensir
//
//  Stand-ins for screenshots in the Simulator, which has no camera: a drawn
//  camera view with a real QR code on a printed card, demo history, and a
//  photo with several codes in it. Only reachable through the Debug launch
//  arguments in LensirApp.swift.
//

import CoreImage.CIFilterBuiltins
import SwiftData
import SwiftUI

enum DemoScene: String {
    case looking, found, safe, risky, http, wifi, contact, phone, text, photos

    var payload: String? {
        switch self {
        case .looking, .photos: nil
        case .found, .safe: "https://paystack.com/pay/kola-logistics"
        // The "a" after "payst" is Cyrillic (U+0430).
        case .risky: "https://payst\u{0430}ck.com/pay"
        case .http: "http://bit.ly/3kQ9xZp"
        case .wifi: "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;"
        case .contact: "MECARD:N:Okafor,Ada;TEL:+2348031234567;EMAIL:ada@kolalogistics.ng;ORG:Kola Logistics;;"
        case .phone: "tel:+2348031234567"
        case .text: "Gate code 4417. Ring twice, then wait by the blue door."
        }
    }

    /// Scenes that open the result sheet, not just the pill.
    var opensSheet: Bool {
        switch self {
        case .looking, .found, .photos: false
        default: true
        }
    }
}

enum DemoContent {
    static func qrImage(_ text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }

    static func seedHistory(in context: ModelContext) {
        let now = Date.now
        let calendar = Calendar.current
        func at(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        let samples: [(String, String, Date)] = [
            ("https://paystack.com/pay/kola-logistics", "QR", min(at(daysAgo: 0, hour: 9, minute: 41), now)),
            ("WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;", "QR", min(at(daysAgo: 0, hour: 8, minute: 12), now)),
            ("https://payst\u{0430}ck.com/pay", "QR", at(daysAgo: 1, hour: 18, minute: 5)),
            ("MECARD:N:Okafor,Ada;TEL:+2348031234567;EMAIL:ada@kolalogistics.ng;ORG:Kola Logistics;;", "QR", at(daysAgo: 1, hour: 13, minute: 30)),
            ("http://bit.ly/3kQ9xZp", "QR", at(daysAgo: 3, hour: 11, minute: 2)),
            ("5901234123457", "EAN-13", at(daysAgo: 3, hour: 10, minute: 47)),
            ("tel:+2348031234567", "QR", at(daysAgo: 6, hour: 16, minute: 20)),
        ]
        for (raw, symbology, date) in samples {
            context.insert(ScanRecord(raw: raw, symbology: symbology, date: date))
        }
    }

    /// A photo of a noticeboard with three codes pinned to it.
    static func photoWithCodes() -> Data? {
        let payloads = ["https://paystack.com/pay/kola-logistics", "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;", "https://payst\u{0430}ck.com/pay"]
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor(red: 0.85, green: 0.82, blue: 0.76, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, payload) in payloads.enumerated() {
                guard let code = qrImage(payload) else { continue }
                let card = CGRect(x: 60 + CGFloat(index) * 380, y: 220 + CGFloat(index % 2) * 120, width: 320, height: 360)
                UIColor.white.setFill()
                context.fill(card)
                context.cgContext.interpolationQuality = .none
                UIImage(cgImage: code).draw(in: card.insetBy(dx: 30, dy: 50).offsetBy(dx: 0, dy: -10))
            }
        }
        return image.pngData()
    }
}

/// The stand-in camera: a dim warm room with a printed code on a card, like
/// the one in the approved design. The card's QR code is real, so the
/// photo flow and the pill both run on actual data.
struct DemoCameraView: View {
    var payload: String?
    var codeFrame: (CGRect) -> Void

    var body: some View {
        GeometryReader { proxy in
            let window = ScanGeometry.lookingFrame(in: proxy.size).rect
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0x3B / 255, green: 0x36 / 255, blue: 0x31 / 255), location: 0),
                        .init(color: Color(red: 0x26 / 255, green: 0x28 / 255, blue: 0x2B / 255), location: 0.55),
                        .init(color: Color(red: 0x12 / 255, green: 0x14 / 255, blue: 0x17 / 255), location: 1),
                    ],
                    startPoint: .top, endPoint: UnitPoint(x: 0.3, y: 1)
                )
                if let payload, let image = DemoContent.qrImage(payload) {
                    card(image: image, side: window.width - 96)
                        .position(x: window.midX, y: window.midY)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The printed card. CoreImage draws a one-module quiet zone around the
    /// code; the reported frame leaves it out, as VisionKit's bounds do.
    private func card(image: CGImage, side: CGFloat) -> some View {
        let module = side / CGFloat(image.width)
        return Image(decorative: image, scale: 1)
            .interpolation(.none)
            .resizable()
            .frame(width: side, height: side)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("screen")) } action: { frame in
                codeFrame(frame.insetBy(dx: module, dy: module))
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0xEC / 255, green: 0xE7 / 255, blue: 0xDE / 255)))
    }
}
