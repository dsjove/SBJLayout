import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Pagination behavior")
struct PaginationTests {
	private func pagination() -> Pagination {
		Pagination(size: .custom(width: 100, height: 100))
	}

	@Test("Keep-with moves the preceding group with the current group")
	func keepWithPrevious() {
		let pagination = pagination()
		let first = pagination.registerGroup()
		let second = pagination.registerGroup()
		let third = pagination.registerGroup()

		pagination.measuredGroup(first, CGSize(width: 100, height: 60), behavior: .flow, spacingBefore: 0)
		pagination.measuredGroup(second, CGSize(width: 100, height: 30), behavior: .flow, spacingBefore: 0)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(third, CGSize(width: 100, height: 20), behavior: .keepWith, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)

		// The keep-with relationship forms a 50-point unit, so the second group,
		// not the third, becomes the start of page two.
		_ = pagination.renderingGroup(first, from: .zero)
		let secondOrigin = pagination.renderingGroup(second, from: CGPoint(x: 0, y: 60))
		let thirdOrigin = pagination.renderingGroup(third, from: CGPoint(x: 0, y: 90))
		#expect(secondOrigin.y == 0)
		#expect(thirdOrigin.y == 30)
	}

	@Test("Page behavior forces a new page except for the first group")
	func forcedPage() {
		let pagination = pagination()
		let first = pagination.registerGroup()
		let second = pagination.registerGroup()

		pagination.measuredGroup(first, CGSize(width: 100, height: 20), behavior: .page, spacingBefore: 0)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(second, CGSize(width: 100, height: 20), behavior: .page, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)
	}

	@Test("Flow starts a new page only when the next unit does not fit")
	func flow() {
		let pagination = pagination()
		let first = pagination.registerGroup()
		let second = pagination.registerGroup()
		let third = pagination.registerGroup()

		pagination.measuredGroup(first, CGSize(width: 100, height: 40), behavior: .flow, spacingBefore: 0)
		pagination.measuredGroup(second, CGSize(width: 100, height: 50), behavior: .flow, spacingBefore: 5)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(third, CGSize(width: 100, height: 10), behavior: .flow, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)
	}
}
