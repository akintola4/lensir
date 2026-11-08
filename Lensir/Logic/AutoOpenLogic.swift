//
//  AutoOpenLogic.swift
//  Lensir
//
//  When "Open results right away" is on, whether a code in view should
//  open the drawer by itself. Two rules:
//
//  - Hold still. A code opens once it has stayed in view, with nothing
//    else in the frame, for `steady` seconds. One sliding past doesn't.
//  - Don't pop back. Once you close a code's drawer, that code stays
//    closed while it's still in front of the camera. It opens again only
//    after it has been gone for `leaveGap`, or when a different code turns
//    up. If the camera hasn't reported it at all `restartGrace` after the
//    drawer went away, it has left too.
//
//  Times are seconds on any clock that only goes forward.
//

import Foundation

nonisolated struct AutoOpenLogic: Sendable {
    /// How long a code has to stay in view before it opens.
    static let steady: TimeInterval = 0.25
    /// How long a closed code has to be out of view to count as gone. The
    /// same wait the pill uses before it lets go of a code.
    static let leaveGap: TimeInterval = 0.7
    /// The camera starts again when the drawer has gone. If it hasn't seen
    /// the closed code by this long after, the code isn't there any more.
    static let restartGrace: TimeInterval = 1.5

    /// A code waiting to be steady.
    private(set) var candidate: (raw: String, since: TimeInterval)?
    /// The code whose drawer was just closed, while it may still be in view.
    private(set) var held: String?
    private var closedAt: TimeInterval = 0
    private var heldSeenSinceClose = false
    /// When the camera last said it saw nothing, while a code is held.
    private var absentSince: TimeInterval?

    init() {}

    /// The camera sees `raw`. Returns true when it should open now.
    mutating func seen(_ raw: String, at time: TimeInterval, enabled: Bool) -> Bool {
        guard enabled else {
            candidate = nil
            return false
        }
        if let held {
            if raw != held {
                release()
            } else if hasLeft(at: time) {
                release()
            } else {
                heldSeenSinceClose = true
                absentSince = nil
                return false
            }
        }
        if candidate?.raw != raw { candidate = (raw, time) }
        return check(at: time, enabled: enabled)
    }

    /// The camera sees nothing.
    mutating func lost(at time: TimeInterval) {
        candidate = nil
        if held != nil, absentSince == nil { absentSince = time }
    }

    /// Asked again on a timer, since a code held perfectly still may not
    /// be reported again. True when the waiting code has been steady long enough.
    mutating func check(at time: TimeInterval, enabled: Bool) -> Bool {
        guard enabled, let candidate, held == nil, time - candidate.since >= Self.steady else { return false }
        self.candidate = nil
        return true
    }

    /// A drawer opened, by itself or from the pill: stop waiting.
    mutating func opened() {
        candidate = nil
    }

    /// A camera code's drawer has gone and the camera is starting again.
    mutating func closed(_ raw: String, at time: TimeInterval) {
        candidate = nil
        held = raw
        closedAt = time
        heldSeenSinceClose = false
        absentSince = nil
    }

    private func hasLeft(at time: TimeInterval) -> Bool {
        if let absentSince { return time - absentSince >= Self.leaveGap }
        return !heldSeenSinceClose && time - closedAt >= Self.restartGrace
    }

    private mutating func release() {
        held = nil
        absentSince = nil
        heldSeenSinceClose = false
    }
}
