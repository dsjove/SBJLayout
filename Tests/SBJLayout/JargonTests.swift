import Testing
@testable import SBJLayout

@Suite("Jargon")
struct JargonTests {
	@Test("Words fall back to their key and preserve nil")
	func wordFallback() {
		let jargon = Jargon("Test", words: ["armor": "Armor Class"])

		#expect(jargon.text("armor") == "Armor Class")
		#expect(jargon.text("unknown") == "unknown")
		#expect(jargon.text(nil) == nil)
	}

	@Test("Overrides replace definitions and retain the base")
	func override() {
		let base = Jargon(
			"Base",
			words: [
				"armor": "Armor Class",
				"health": "Hit Points",
			],
			formatters: [
				"modifier": JargonFormatter(Int.self) { value in
					value >= 0 ? "+\(value)" : "\(value)"
				}
			]
		)
		let compact = Jargon(
			"Compact",
			overriding: base,
			words: ["armor": "AC"]
		)

		#expect(compact.text("armor") == "AC")
		#expect(compact.text("health") == "Hit Points")
		#expect(compact.format("modifier", value: 3) == "+3")
	}

	@Test("Nullable formatter key preserves nil")
	func nullableFormatterKey() {
		let jargon = Jargon(
			"Test",
			formatters: [
				"modifier": JargonFormatter(Int.self) { String($0) }
			]
		)

		#expect(jargon.format("modifier", value: 3) == "3")
		#expect(jargon.format(nil, value: 3) == nil)
	}

	@Test("Scoped jargon overrides restore the parent context")
	func scopedContext() {
		let outer = Jargon("Outer", words: ["armor": "Armor"])
		let inner = Jargon("Inner", overriding: outer, words: ["armor": "AC"])

		RenderableEnvironment.withContext(jargon: outer) {
			#expect(RenderableEnvironment.context.jargon.text("armor") == "Armor")

			RenderableEnvironment.withContext(jargon: inner) {
				#expect(RenderableEnvironment.context.jargon.text("armor") == "AC")
			}

			#expect(RenderableEnvironment.context.jargon.text("armor") == "Armor")
		}
	}
}
