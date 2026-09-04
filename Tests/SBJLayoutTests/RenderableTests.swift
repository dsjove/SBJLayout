import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Renderable")
struct RenderableTests {
	private struct Stub: Renderable {
		let id: Int

		func measure(bounds: CGSize) -> CGSize { .zero }
		func render(in allocated: CGRect, measured: CGSize, align: Alignment) {}
	}

	private func build(@RenderableBuilder _ content: () -> Renderables) -> Renderables {
		content()
	}

	@Test("RenderableBuilder flattens expressions, arrays, optionals, conditions, and loops")
	func flattenedBuilder() {
		let includeOptional = true
		let values = build {
			Stub(id: 1)
			[Stub(id: 2), Stub(id: 3)]
			if includeOptional { Stub(id: 4) }
			for id in 5...6 { Stub(id: id) }
		}

		let ids = values.compactMap { ($0 as? Stub)?.id }
		#expect(ids == [1, 2, 3, 4, 5, 6])
	}

	@Test("RenderableBuilder omits nil optional branches")
	func flattenedBuilderOmitsNil() {
		let includeOptional = false
		let values = build {
			Stub(id: 1)
			if includeOptional { Stub(id: 2) }
			Stub(id: 3)
		}

		let ids = values.compactMap { ($0 as? Stub)?.id }
		#expect(ids == [1, 3])
	}
}
