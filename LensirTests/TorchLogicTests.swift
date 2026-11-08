//
//  TorchLogicTests.swift
//  LensirTests
//

import AVFoundation
import Testing
@testable import Lensir

struct TorchLogicTests {
    /// The torch goes on the device VisionKit's session runs, or the session
    /// is interrupted and the picture freezes (seen on an iPhone 12 Pro, where
    /// only the triple camera left the scanner running).
    @Test func visionKitPrefersTheMostCapableVirtualCamera() {
        #expect(TorchLogic.deviceTypes(visionKit: true) == [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera])
    }

    @Test func theFallbackUsesTheDefaultWideCamera() {
        #expect(TorchLogic.deviceTypes(visionKit: false) == [.builtInWideAngleCamera])
    }
}
