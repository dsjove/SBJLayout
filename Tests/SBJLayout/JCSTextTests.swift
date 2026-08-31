import Foundation
import Testing
import UIKit
@testable import SBJLayout

@Suite("JCSText")
struct JCSTextTests {
    @Test("Stored attributed content is immutable so copied values do not share mutable render state")
    func storedContentIsImmutable() {
        let text = JCSText(verbatim: "value semantics", font: UIFont.systemFont(ofSize: 12))
        let content = Mirror(reflecting: text).children.first { $0.label == "content" }?.value
        let unwrapped = Mirror(reflecting: content as Any).displayStyle == .optional
            ? Mirror(reflecting: content as Any).children.first?.value
            : content

        #expect(unwrapped is NSAttributedString)
        #expect(!(unwrapped is NSMutableAttributedString))
    }
}

@Suite("String")
struct StringTests {
	@Test("Limiting explicit lines truncates at the requested line count")
	func limitingExplicitLinesTruncates() {
		let text = "one\ntwo\nthree\nfour\nfive"

		#expect(text.limitingExplicitLines(to: 3) == "one\ntwo\nthree")
	}

	@Test("Limiting explicit lines preserves text within the limit")
	func limitingExplicitLinesPreservesShortText() {
		let text = "one\ntwo\nthree"

		#expect(text.limitingExplicitLines(to: 3) == text)
	}

	@Test("Empty lines count as explicit lines")
	func limitingExplicitLinesCountsEmptyLines() {
		let text = "one\n\nthree\nfour"

		#expect(text.limitingExplicitLines(to: 3) == "one\n\nthree")
	}

	@Test("Nil line limit does not truncate")
	func limitingExplicitLinesWithNilLimit() {
		let text = "one\ntwo\nthree"

		#expect(text.limitingExplicitLines(to: nil) == text)
	}

	@Test("Unlimited line limit does not truncate")
	func limitingExplicitLinesWithUnlimitedLimit() {
		let text = "one\ntwo\nthree"

		#expect(text.limitingExplicitLines(to: Int.max) == text)
	}
}
