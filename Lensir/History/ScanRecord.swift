//
//  ScanRecord.swift
//  Lensir
//
//  One opened code, kept on the phone. Only the raw text is stored; what it
//  is and whether it's safe are worked out again when the list is shown, so
//  better checks in a later version apply to old scans too.
//

import Foundation
import SwiftData

@Model
final class ScanRecord {
    var raw: String
    var symbology: String
    var date: Date

    init(raw: String, symbology: String, date: Date = .now) {
        self.raw = raw
        self.symbology = symbology
        self.date = date
    }
}
