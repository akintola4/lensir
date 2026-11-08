//
//  LensirApp.swift
//  Lensir
//
//  Lensir reads QR codes and barcodes on the phone, shows you what's inside
//  before anything opens, and checks links for the tricks scam codes use.
//  No network code, no account. History stays on the phone.
//

import SwiftData
import SwiftUI

@main
struct LensirApp: App {
    @State private var settings = AppSettings()
    private let inbox = LinkInbox.shared
    private let container = LensirStore.makeContainer()

    var body: some Scene {
        WindowGroup {
            ScannerScreen(settings: settings, inbox: inbox)
                .onOpenURL { inbox.receive($0) }
        }
        .modelContainer(container)
    }
}

enum LensirStore {
    static func makeContainer() -> ModelContainer {
        let inMemory = LaunchOptions.demo != nil || LaunchOptions.openHistory
        // Stay in the app's own container. With an App Group in the
        // entitlements, SwiftData's default would move the store into the
        // group and leave the history already on the phone behind.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, groupContainer: .none)
        let container: ModelContainer
        do {
            // My codes share the store with History.
            container = try ModelContainer(for: ScanRecord.self, MadeCode.self, configurations: configuration)
        } catch {
            fatalError("Couldn't open the history store: \(error)")
        }
        if LaunchOptions.openHistory && !LaunchOptions.emptyHistory {
            DemoContent.seedHistory(in: container.mainContext)
            if !LaunchOptions.emptyCodes { DemoContent.seedCodes(in: container.mainContext) }
        }
        return container
    }
}

// MARK: - Launch arguments

/// Debug-only switches for screenshots, set in the scheme or passed to
/// `simctl launch`. The Simulator has no camera, so the demo scenes draw a
/// stand-in camera with a real QR code on it. Demo runs keep history in
/// memory, so nothing is saved.
enum LaunchOptions {
    /// `-LensirDemo found`: open on a demo scene. One of `looking`, `found`,
    /// `safe`, `risky`, `http`, `wifi`, `contact`, `phone`, `text`, `photos`,
    /// `live` (a code reported like a real camera's), or `make-link`, `make-wifi`, `make-risky`, `make-show` for Make.
    static var demo: DemoScene? { value(after: "-LensirDemo").flatMap(DemoScene.init(rawValue:)) }

    /// `-LensirNoCamera`: act as if the phone has no camera.
    static var noCamera: Bool { flag("-LensirNoCamera") }

    /// `-LensirCameraDenied`: act as if camera access was turned off in Settings.
    static var cameraDenied: Bool { flag("-LensirCameraDenied") }

    /// `-LensirOpenHistory`: open the history list on launch, filled with demo scans.
    static var openHistory: Bool { flag("-LensirOpenHistory") }

    /// `-LensirEmptyHistory`: with -LensirOpenHistory, leave the list empty.
    static var emptyHistory: Bool { flag("-LensirEmptyHistory") }

    /// `-LensirEmptyCodes`: with -LensirOpenHistory, fill in scans but no My codes.
    static var emptyCodes: Bool { flag("-LensirEmptyCodes") }

    /// `-LensirAutoOpen`: turn on "Open results right away" for this run,
    /// without saving it.
    static var autoOpen: Bool { flag("-LensirAutoOpen") }

    /// `-LensirNoSplash`: open straight on the scanner, for screenshots.
    static var skipSplash: Bool { flag("-LensirNoSplash") }

    /// `-LensirSplashSlow`: play the opening animation 4× slower, for tuning it.
    static var splashSlowdown: Double { flag("-LensirSplashSlow") ? 4 : 1 }

    /// `-LensirDrawerSlow`: run the drawers' springs 4× slower, so a UI test
    /// has time to catch one mid-flight.
    static var drawerSlowdown: Double { flag("-LensirDrawerSlow") ? 4 : 1 }

    /// `-LensirSplashAt 0.3`: hold the opening animation at this many seconds
    /// in, for stills. It never moves on to the scanner.
    static var splashFrozenAt: Double? { value(after: "-LensirSplashAt").flatMap(Double.init) }

    private static func flag(_ name: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(name)
        #else
        false
        #endif
    }

    private static func value(after name: String) -> String? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
        #else
        nil
        #endif
    }
}
