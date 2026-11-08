//
//  FirstFrames.swift
//  Lensir
//
//  Waits for the screen to start drawing this app. The scene says "active"
//  before iOS has shown a single frame of it (on a first launch, sometimes
//  for longer than the whole opening animation), so the animation's clock
//  starts on the display's own ticks instead.
//

import QuartzCore

enum FirstFrames {
    /// Resumes after `count` display refreshes in which this app drew.
    static func wait(_ count: Int = 2) async {
        await withCheckedContinuation { continuation in
            Ticker(count: count) { continuation.resume() }.start()
        }
    }

    private final class Ticker: NSObject {
        private var remaining: Int
        private var link: CADisplayLink?
        private var done: (() -> Void)?

        init(count: Int, done: @escaping () -> Void) {
            remaining = count
            self.done = done
        }

        func start() {
            // The link holds the ticker until it's invalidated.
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            self.link = link
        }

        @objc private func tick() {
            remaining -= 1
            guard remaining <= 0 else { return }
            link?.invalidate()
            link = nil
            done?()
            done = nil
        }
    }
}
