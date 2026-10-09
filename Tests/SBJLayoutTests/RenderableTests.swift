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
    @Test("Array renderables maps and flattens builder output")
    func arrayRenderableMapping() {
        let values = [1, 2, 3].renderables { id in
            Stub(id: id)
            if id.isMultiple(of: 2) {
                Stub(id: id * 10)
            }
        }

        #expect(values.compactMap { ($0 as? Stub)?.id } == [1, 2, 20, 3])
    }

    @Test("Array renderables supports empty arrays and empty builder output")
    func arrayRenderableMappingEmpty() {
        let empty = [Int]().renderables { id in
            Stub(id: id)
        }
        let omitted = [1, 2].renderables { id in
            if id > 2 { Stub(id: id) }
        }
        #expect(empty.isEmpty)
        #expect(omitted.isEmpty)
    }

}
