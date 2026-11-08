//
//  CheckChipsTests.swift
//  LensirTests
//
//  The chips under a link: failures first, each check's label and full
//  title, and when they start to arrive.
//

import Testing
@testable import Lensir

@Suite("Check chips")
struct CheckChipsTests {
    @Test func failuresComeFirstInTheirUsualOrder() {
        // Cyrillic "а", a brand in front of the real site, too many subdomains, http.
        let chips = CheckChips.ordered(LinkSafety.check("http://payst\u{0430}ck.com.secure-login.verify.ng-pay.xyz/pay"))
        let failed = chips.prefix { !$0.passed }
        #expect(failed.map(\.label) == ["https", "Plain letters", "Few subdomains"])
        #expect(chips.dropFirst(failed.count).allSatisfy { $0.passed })
        #expect(chips.count == 9)
    }

    @Test func passesKeepTheirOrder() {
        let chips = CheckChips.ordered(LinkSafety.check("http://bit.ly/3kQ9xZp"))
        #expect(chips.map(\.label) == ["https", "Not shortened", "Web address", "Named site", "Real site",
                                       "Plain letters", "No @ trick", "Few subdomains", "Real-looking name"])
    }

    @Test func aCleanLinkIsAllPasses() {
        let chips = CheckChips.ordered(LinkSafety.check("https://paystack.com/pay"))
        #expect(chips == ResultDetails.checks(for: LinkSafety.check("https://paystack.com/pay")))
        #expect(chips.allSatisfy { $0.passed })
    }

    @Test func aScriptIsOneFailedChip() {
        #expect(CheckChips.ordered(LinkSafety.check("javascript:alert(1)")).map(\.label) == ["Web address"])
    }

    @Test func everyLabelIsShortAndEveryTitleIsWhole() {
        let chips = ResultDetails.checks(for: LinkSafety.check("https://paystack.com/pay"))
        #expect(Set(chips.map(\.label)).count == chips.count)
        #expect(chips.allSatisfy { $0.label.count <= 17 && $0.title.count > $0.label.count })
    }

    @Test func chipsFollowOneAnotherAtTheStagger() {
        #expect(CheckChips.delay(for: 0) == 0)
        #expect(abs(CheckChips.delay(for: 4) - 0.18) < 1e-9)
        #expect(CheckChips.delay(for: -1) == 0)
    }

    @Test func theyStartAsTheDrawerNearlyLands() {
        #expect(!CheckChips.hasLanded(height: 0, compact: 0))
        #expect(!CheckChips.hasLanded(height: 300, compact: 400))
        #expect(CheckChips.hasLanded(height: 340, compact: 400))
        #expect(CheckChips.hasLanded(height: 400, compact: 400))
    }
}
