//
//  MadeCode.swift
//  Lensir
//
//  A code you made and kept, in My codes. It lives in the same store as
//  History. Only the text in the code and your name for it are stored; the
//  picture is drawn again whenever it's shown.
//

import Foundation
import SwiftData

@Model
final class MadeCode {
    var raw: String
    var name: String
    var date: Date

    init(raw: String, name: String, date: Date = .now) {
        self.raw = raw
        self.name = name
        self.date = date
    }
}
