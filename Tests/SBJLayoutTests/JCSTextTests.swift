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

@Suite("JCSText minimum measurement")
struct JCSTextMinimumMeasureTests {
    private let font = UIFont.systemFont(ofSize: 12)

    @Test("Single unbreakable word has the same minimum and preferred width")
    func singleWordMinimumMatchesPreferred() {
        let text = JCSText(verbatim: "Damage", font: font)

        let preferred = text.measure()
        let minimum = text.minimumMeasure()

        #expect(minimum.width == preferred.width)
    }

    @Test("Word-wrapped prose has a narrower minimum width than preferred width")
    func wordWrappingFindsNarrowerMinimum() {
        let text = JCSText(
            verbatim: "The target takes additional damage and must make a saving throw.",
            font: font,
            lineBreakMode: .byWordWrapping
        )

        let preferred = text.measure()
        let minimum = text.minimumMeasure()

        #expect(minimum.width > 0)
        #expect(minimum.width < preferred.width)
    }

    @Test("Explicit lines use the widest minimum-content line")
    func explicitLinesUseWidestMinimumLine() {
        let first = JCSText(verbatim: "short", font: font)
        let second = JCSText(verbatim: "considerablylongerword", font: font)
        let combined = JCSText(verbatim: "short\nconsiderablylongerword", font: font)

        let expected = max(first.minimumMeasure().width, second.minimumMeasure().width)
        let measured = combined.minimumMeasure().width

        #expect(measured == expected)
    }

    @Test("Character wrapping can produce a smaller minimum than word wrapping")
    func characterWrappingHasSmallerMinimum() {
        let value = "unbreakabletoken"
        let wordWrapped = JCSText(verbatim: value, font: font, lineBreakMode: .byWordWrapping)
        let characterWrapped = JCSText(verbatim: value, font: font, lineBreakMode: .byCharWrapping)

        #expect(characterWrapped.minimumMeasure().width < wordWrapped.minimumMeasure().width)
    }

    @Test("Punctuation-only word wrapping does not collapse to zero")
    func punctuationOnlyDoesNotCollapse() {
        let text = JCSText(verbatim: "---", font: font, lineBreakMode: .byWordWrapping)

        #expect(text.minimumMeasure().width > 0)
    }

    @Test("Finite bounds cap pathological minimum width")
    func finiteBoundsCapLongToken() {
        let text = JCSText(
            verbatim: String(repeating: "W", count: 10_000),
            font: font,
            lineBreakMode: .byWordWrapping
        )
        let cap: CGFloat = 120

        let minimum = text.minimumMeasure(bounds: .init(width: cap, height: .unbounded))

        #expect(minimum.width <= cap)
        #expect(minimum.width > 0)
    }

    @Test("Truncating text preserves existing measurement semantics")
    func truncationPreservesMeasurement() {
        let text = JCSText(
            verbatim: "A long label that is allowed to truncate",
            font: font,
            lineBreakMode: .byTruncatingTail
        )
        let bounds = CGSize(width: 90, height: .unbounded)

        #expect(text.minimumMeasure(bounds: bounds) == text.measure(bounds: bounds))
    }

    @Test("minChars remains a content-driven minimum")
    func minimumCharactersAreRespected() {
        let withoutMinimum = JCSText(verbatim: "HP", font: font)
        let withMinimum = JCSText(verbatim: "HP", font: font, minChars: 8)

        #expect(withMinimum.minimumMeasure().width > withoutMinimum.minimumMeasure().width)
    }
}
