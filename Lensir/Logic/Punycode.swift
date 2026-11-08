//
//  Punycode.swift
//  Lensir
//
//  Decodes `xn--` labels (RFC 3492) so an address like xn--pystack-2fg.com is
//  shown, and checked, as the letters it's pretending to be.
//

nonisolated enum Punycode {
    private static let base = 36, tMin = 1, tMax = 26, skew = 38, damp = 700
    private static let initialBias = 72, initialN = 128

    /// Decodes one label without its `xn--` prefix. Nil if it isn't valid Punycode.
    static func decode(_ label: String) -> String? {
        let scalars = Array(label.unicodeScalars)
        var output: [UnicodeScalar] = []
        var start = 0
        if let dash = scalars.lastIndex(of: "-") {
            for scalar in scalars[..<dash] {
                guard scalar.isASCII else { return nil }
                output.append(scalar)
            }
            start = dash + 1
        }
        var n = initialN, i = 0, bias = initialBias
        var position = start
        while position < scalars.count {
            let oldI = i
            var w = 1
            var k = base
            while true {
                guard position < scalars.count, let digit = digitValue(scalars[position]) else { return nil }
                position += 1
                let (product, overflowA) = digit.multipliedReportingOverflow(by: w)
                let (sum, overflowB) = i.addingReportingOverflow(product)
                guard !overflowA, !overflowB else { return nil }
                i = sum
                let t = k <= bias ? tMin : (k >= bias + tMax ? tMax : k - bias)
                if digit < t { break }
                w *= base - t
                k += base
            }
            bias = adapt(delta: i - oldI, count: output.count + 1, first: oldI == 0)
            n += i / (output.count + 1)
            i %= output.count + 1
            guard let scalar = UnicodeScalar(n) else { return nil }
            output.insert(scalar, at: i)
            i += 1
        }
        var result = ""
        result.unicodeScalars.append(contentsOf: output)
        return result
    }

    /// Decodes every `xn--` label in a host name, leaving the rest alone.
    static func decodeHost(_ host: String) -> String {
        host.split(separator: ".", omittingEmptySubsequences: false).map { label in
            let text = String(label)
            guard text.lowercased().hasPrefix("xn--") else { return text }
            return decode(String(text.dropFirst(4))) ?? text
        }.joined(separator: ".")
    }

    private static func digitValue(_ scalar: UnicodeScalar) -> Int? {
        switch scalar.value {
        case 0x30...0x39: Int(scalar.value) - 22      // 0-9 → 26-35
        case 0x41...0x5A: Int(scalar.value) - 0x41    // A-Z → 0-25
        case 0x61...0x7A: Int(scalar.value) - 0x61    // a-z → 0-25
        default: nil
        }
    }

    private static func adapt(delta: Int, count: Int, first: Bool) -> Int {
        var delta = first ? delta / damp : delta / 2
        delta += delta / count
        var k = 0
        while delta > ((base - tMin) * tMax) / 2 {
            delta /= base - tMin
            k += base
        }
        return k + (base - tMin + 1) * delta / (delta + skew)
    }
}
