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
    case safeExpanded = "safe-expanded"
    case riskyExpanded = "risky-expanded"
    case wifiExpanded = "wifi-expanded"
    case contactExpanded = "contact-expanded"
    /// A long payment link, expanded: Details run past the screen and
    /// scroll, for the drawer's scroll-handoff tests.
    case longExpanded = "long-expanded"
    /// Plays through the drawer by itself, for recording: the brackets snap,
    /// the drawer rises, expands, settles back and is flicked away.
    case drawerTour = "drawer-tour"
    /// The Make drawer, filled in: a link, the Kola Logistics Wi-Fi, a
    /// lookalike link with its warning, and the Wi-Fi shown full screen.
    case makeLink = "make-link"
    case makeWiFi = "make-wifi"
    case makeRisky = "make-risky"
    case makeShow = "make-show"

    var payload: String? {
        switch self {
        case .looking, .photos, .makeLink, .makeWiFi, .makeRisky, .makeShow: nil
        case .found, .safe, .safeExpanded, .drawerTour: "https://paystack.com/pay/kola-logistics"
        // The "a" after "payst" is Cyrillic (U+0430).
        case .risky, .riskyExpanded: "https://payst\u{0430}ck.com/pay"
        case .http: "http://bit.ly/3kQ9xZp"
        case .wifi, .wifiExpanded: "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;"
        case .contact, .contactExpanded: "MECARD:N:Okafor,Ada;TEL:+2348031234567;EMAIL:ada@kolalogistics.ng;ORG:Kola Logistics;URL:https://kolalogistics.ng;ADR:12 Allen Ave\\, Ikeja\\, Lagos;;"
        case .longExpanded:
            "https://paystack.com/pay/kola-logistics?invoice=INV-2026-11-0417&customer=ada.okafor%40kolalogistics.ng"
                + "&amount=125000&currency=NGN&due=2026-11-30&utm_source=printed-invoice&utm_medium=qr"
                + "&utm_campaign=november-statements&utm_content=footer-code&reference=KL-7f3c2a91b8e44d0c9a6e1f5b2d8c4a07"
                + "&callback=https%3A%2F%2Fkolalogistics.ng%2Fpayments%2Fthank-you%3Fsession%3D3b9d1e6f0a7c4b2e8d5f9a1c6e3b7d40"
                + "%26source%3Dqr%26lang%3Den-NG%26return%3D%252Faccount%252Finvoices%252FINV-2026-11-0417"
        case .phone: "tel:+2348031234567"
        case .text: "Gate code 4417. Ring twice, then wait by the blue door."
        }
    }

    /// Scenes that open with the drawer already up, not just the pill.
    var opensSheet: Bool {
        switch self {
        case .looking, .found, .photos, .drawerTour, .makeLink, .makeWiFi, .makeRisky, .makeShow: false
        default: true
        }
    }

    var expandsDrawer: Bool {
        switch self {
        case .safeExpanded, .riskyExpanded, .wifiExpanded, .contactExpanded, .longExpanded: true
        default: false
        }
    }
}

extension DemoScene {
    /// What the Make scenes open with already typed.
    var makeDraft: CodeDraft? {
        switch self {
        case .makeLink: CodeDraft(kind: .link, link: "kolalogistics.test/track")
        case .makeWiFi, .makeShow: CodeDraft(kind: .wifi, ssid: "Kola Logistics", password: "jollof-2026")
        // The "a" after "payst" is Cyrillic (U+0430).
        case .makeRisky: CodeDraft(kind: .link, link: "https://payst\u{0430}ck.com/pay/kola-logistics")
        default: nil
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

    /// My codes: the office Wi-Fi for guests, the tracking page, the front desk.
    static func seedCodes(in context: ModelContext) {
        let now = Date.now
        let calendar = Calendar.current
        let codes: [(String, String, Int)] = [
            ("WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;", "Kola Logistics", 0),
            ("https://kolalogistics.test/track", "kolalogistics.test", 2),
            ("tel:+2348060000000", "+234 806 000 0000", 9),
        ]
        for (raw, name, daysAgo) in codes {
            context.insert(MadeCode(raw: raw, name: name, date: calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now))
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
                LinearGradient(stops: LaunchOptions.brightScene ? Self.brightRoom : Self.dimRoom,
                               startPoint: .top, endPoint: UnitPoint(x: 0.3, y: 1))
                if let payload, let image = DemoContent.qrImage(payload) {
                    card(image: image, side: window.width - 96)
                        .position(x: window.midX, y: window.midY)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// A dim, warm room: the scene the approved design was drawn over.
    private static let dimRoom: [Gradient.Stop] = [
        .init(color: Color(red: 0x3B / 255, green: 0x36 / 255, blue: 0x31 / 255), location: 0),
        .init(color: Color(red: 0x26 / 255, green: 0x28 / 255, blue: 0x2B / 255), location: 0.55),
        .init(color: Color(red: 0x12 / 255, green: 0x14 / 255, blue: 0x17 / 255), location: 1),
    ]

    /// A sunlit wall, for -LensirBrightScene.
    private static let brightRoom: [Gradient.Stop] = [
        .init(color: Color(red: 0xF4 / 255, green: 0xF1 / 255, blue: 0xEA / 255), location: 0),
        .init(color: Color(red: 0xE6 / 255, green: 0xE3 / 255, blue: 0xDC / 255), location: 0.55),
        .init(color: Color(red: 0xD2 / 255, green: 0xD0 / 255, blue: 0xCB / 255), location: 1),
    ]

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
