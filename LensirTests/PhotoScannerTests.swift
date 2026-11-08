//
//  PhotoScannerTests.swift
//  LensirTests
//
//  Reading codes from a photo goes through Vision for real: a drawn photo
//  with three codes in it should give back all three, in reading order.
//  The middle card hangs lower than the other two, so it comes last.
//

import Foundation
import Testing
@testable import Lensir

@MainActor
@Suite("From a photo")
struct PhotoScannerTests {
    @Test func findsEveryCodeInOrder() async throws {
        let data = try #require(DemoContent.photoWithCodes())
        let codes = await PhotoScanner.codes(in: data)
        #expect(codes.map(\.raw) == [
            "https://paystack.com/pay/kola-logistics",
            "https://payst\u{0430}ck.com/pay",
            "WIFI:T:WPA;S:Kola Logistics;P:jollof-2026;;",
        ])
        #expect(codes.allSatisfy { $0.symbology == "QR" && $0.thumbnail != nil })
    }

    @Test func photoWithoutCodesFindsNothing() async {
        #expect(await PhotoScanner.codes(in: Data("not an image".utf8)).isEmpty)
    }
}
