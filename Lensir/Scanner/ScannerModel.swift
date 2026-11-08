//
//  ScannerModel.swift
//  Lensir
//
//  The scanner's state: which camera is running, the code in view, and the
//  result that's open. The camera views report codes in; the screen reads
//  this to place the brackets, the pill and the sheet.
//

import SwiftUI

/// A code the camera can see right now, in screen points.
struct Detection: Equatable {
    var raw: String
    var symbology: String
    var bounds: CGRect
}

/// A code that's been opened into the sheet.
struct ScanResult: Identifiable, Equatable {
    enum Source { case camera, photo, history }

    let id = UUID()
    var raw: String
    var symbology: String
    var payload: Payload
    var summary: ResultSummary
    var source: Source
    var scannedAt: Date

    init(raw: String, symbology: String, source: Source, scannedAt: Date = .now) {
        self.raw = raw
        self.symbology = symbology
        self.source = source
        self.scannedAt = scannedAt
        payload = PayloadParser.parse(raw)
        summary = ResultLogic.summary(for: payload, raw: raw, symbology: symbology, canJoinWiFi: WiFiJoiner.isAvailable)
    }
}

@Observable
final class ScannerModel {
    enum Camera: Equatable {
        case checking
        case dataScanner
        case capture
        case denied
        case unavailable
        case demo
    }

    var camera: Camera = .checking
    private(set) var detection: Detection?
    /// Worked out once per new code, not on every camera frame.
    private(set) var detectionSummary: ResultSummary?
    var result: ScanResult?
    var torchOn = false
    /// Goes up each time a new code is found; drives the haptic.
    private(set) var foundCount = 0
    /// A short line in place of the hint, like "No code in that photo".
    var notice: String?
    /// Several codes in one photo: the list to pick from.
    var photoCodes: [PhotoCode] = []
    var reduceMotion = false

    private var lostTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?

    /// The camera sees a code. A new one snaps the brackets onto it with a
    /// haptic; the same one moving just pulls them along.
    func found(_ new: Detection) {
        guard result == nil else { return }
        lostTask?.cancel()
        let isNew = detection?.raw != new.raw
        if isNew {
            foundCount += 1
            let summary = Self.summary(new)
            withAnimation(reduceMotion ? Motion.fade : Motion.snap) {
                detection = new
                detectionSummary = summary
            }
            AccessibilityNotification.Announcement("Found \(summary.kindLabel.lowercased()): \(summary.title)").post()
        } else if detection != new {
            withAnimation(reduceMotion ? nil : Motion.track) { detection = new }
        }
    }

    /// The code left the frame. Wait a moment before letting go, so a shaky
    /// hand doesn't make the pill flicker away just as you reach for it.
    func lost() {
        guard result == nil, detection != nil else { return }
        lostTask?.cancel()
        lostTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) {
                detection = nil
                detectionSummary = nil
            }
        }
    }

    /// The pill was tapped. The drawer animates itself up from the edge.
    func openDetection() {
        guard let detection else { return }
        lostTask?.cancel()
        withAnimation(Motion.fade) {
            result = ScanResult(raw: detection.raw, symbology: detection.symbology, source: .camera)
        }
    }

    func open(raw: String, symbology: String, source: ScanResult.Source, scannedAt: Date = .now) {
        lostTask?.cancel()
        withAnimation(Motion.fade) {
            detection = nil
            detectionSummary = nil
            result = ScanResult(raw: raw, symbology: symbology, source: source, scannedAt: scannedAt)
        }
    }

    /// The drawer has started closing: let the brackets go back to waiting
    /// while it slides away.
    func releaseDetection() {
        lostTask?.cancel()
        withAnimation(reduceMotion ? Motion.fade : Motion.snap) {
            detection = nil
            detectionSummary = nil
        }
    }

    /// The drawer is gone: drop the result, and the camera starts again.
    func clearResult() {
        result = nil
    }

    /// Put a code found by the demo camera straight into place, without the snap.
    func place(_ detection: Detection) {
        self.detection = detection
        detectionSummary = Self.summary(detection)
    }

    private static func summary(_ detection: Detection) -> ResultSummary {
        ResultLogic.summary(for: PayloadParser.parse(detection.raw), raw: detection.raw, symbology: detection.symbology,
                            canJoinWiFi: WiFiJoiner.isAvailable)
    }

    func show(notice text: String) {
        noticeTask?.cancel()
        withAnimation(Motion.fade) { notice = text }
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            withAnimation(Motion.fade) { notice = nil }
        }
    }
}
