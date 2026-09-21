import CoreGraphics
import Testing
import SBJFoundation
@testable import SBJLayout

@Suite("Tag rendering")
struct TagRenderableTests {
	private let color = CodableColor(0.2, 0.4, 0.8)

	@Test("Empty tags occupy no space")
	func emptyTagMeasuresZero() {
		let tag = TagRenderable(displayName: "", color: color)
		#expect(tag.measure() == .zero)
	}

	@Test("Primary state does not change tag size")
	func primaryStateKeepsStableGeometry() {
		let normal = TagRenderable(displayName: "Arcane", color: color)
		let primary = TagRenderable(displayName: "Arcane", color: color, isPrimary: true)
		#expect(normal.measure() == primary.measure())
	}

	@Test("Bounded tag width truncates instead of expanding to the bound")
	func boundedWidthCapsIntrinsicWidth() {
		let tag = TagRenderable(displayName: "A fairly long tag name", color: color)
		let intrinsic = tag.measure()
		let bound = max(20, intrinsic.width - 15)
		let bounded = tag.measure(bounds: CGSize(width: bound, height: .unbounded))

		#expect(bounded.width <= bound)
		#expect(bounded.width < intrinsic.width)
	}

	@Test("Tag groups wrap horizontally")
	func tagGroupWraps() {
		let tags = ["Alpha", "Bravo", "Charlie", "Delta"].map {
			TagRenderable(displayName: $0, color: color)
		}
		let group = TagGroup(tags)
		let wide = group.measure(bounds: CGSize(width: 2_000, height: .unbounded))
		let widestTag = tags.map { $0.measure().width }.max() ?? 1
		let narrow = group.measure(bounds: CGSize(width: widestTag + 1, height: .unbounded))

		#expect(narrow.height > wide.height)
		#expect(narrow.width <= widestTag + 1)
	}

	@Test("Empty tag groups occupy no space")
	func emptyGroupMeasuresZero() {
		#expect(TagGroup([]).measure() == .zero)
	}
}
