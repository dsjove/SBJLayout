import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Pagination behavior")
struct PaginationTests {
	private func pagination() -> Pagination {
		Pagination(layout: .init(
			pageSize: .custom(width: 100, height: 100),
			margins: .zero
		))
	}

	@Test("Keep-with moves the preceding group with the current group")
	func keepWithPrevious() {
		let pagination = pagination()
		let first = pagination.registerGroup(sectionID: "first")
		let second = pagination.registerGroup(sectionID: "second")
		let third = pagination.registerGroup(sectionID: "third")

		pagination.measuredGroup(first, CGSize(width: 100, height: 60), behavior: .flow, spacingBefore: 0)
		pagination.measuredGroup(second, CGSize(width: 100, height: 30), behavior: .flow, spacingBefore: 0)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(third, CGSize(width: 100, height: 20), behavior: .keepWith, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)

		// The keep-with relationship forms a 50-point unit, so the second group,
		// not the third, becomes the start of page two.
		_ = pagination.renderingGroup(first, frame: CGRect(origin: .zero, size: CGSize(width: 100, height: 60)))
		let secondOrigin = pagination.renderingGroup(second, frame: CGRect(origin: CGPoint(x: 0, y: 60), size: CGSize(width: 100, height: 30)))
		let thirdOrigin = pagination.renderingGroup(third, frame: CGRect(origin: CGPoint(x: 0, y: 90), size: CGSize(width: 100, height: 20)))
		#expect(secondOrigin.y == 0)
		#expect(thirdOrigin.y == 30)
	}

	@Test("Page behavior forces a new page except for the first group")
	func forcedPage() {
		let pagination = pagination()
		let first = pagination.registerGroup(sectionID: "first")
		let second = pagination.registerGroup(sectionID: "second")

		pagination.measuredGroup(first, CGSize(width: 100, height: 20), behavior: .page, spacingBefore: 0)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(second, CGSize(width: 100, height: 20), behavior: .page, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)
	}

	@Test("Flow starts a new page only when the next unit does not fit")
	func flow() {
		let pagination = pagination()
		let first = pagination.registerGroup(sectionID: "first")
		let second = pagination.registerGroup(sectionID: "second")
		let third = pagination.registerGroup(sectionID: "third")

		pagination.measuredGroup(first, CGSize(width: 100, height: 40), behavior: .flow, spacingBefore: 0)
		pagination.measuredGroup(second, CGSize(width: 100, height: 50), behavior: .flow, spacingBefore: 5)
		#expect(pagination.pageNumber == 1)

		pagination.measuredGroup(third, CGSize(width: 100, height: 10), behavior: .flow, spacingBefore: 0)
		#expect(pagination.pageNumber == 2)
	}
	@Test("Horizontal groups paginate by wrapped line height")
	func horizontalLineHeight() {
		let pagination = pagination()
		let intrinsic = pagination.registerGroup(sectionID: "intrinsic")
		let fill = pagination.registerGroup(sectionID: "fill")
		let nextLine = pagination.registerGroup(sectionID: "nextLine")

		pagination.measuredGroup(
			intrinsic,
			CGSize(width: 35, height: 60),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: false
		)
		pagination.measuredGroup(
			fill,
			CGSize(width: 65, height: 30),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: true
		)
		pagination.measuredGroup(
			nextLine,
			CGSize(width: 100, height: 35),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: true
		)

		// The first two groups share one 60-point line, rather than
		// consuming 60 + 30 points independently.
		#expect(pagination.pageNumber == 1)
	}


	@Test("Pagination order follows group registration, not measurement order")
	func registrationOrderSurvivesOutOfOrderMeasurement() {
		let pagination = pagination()
		let intrinsic = pagination.registerGroup(sectionID: "money")
		let fill = pagination.registerGroup(sectionID: "valuables")
		let nextLine = pagination.registerGroup(sectionID: "next")

		// Grid may measure fill and intrinsic tracks in an order different from
		// their declarative/render order. Pagination must not use measurement
		// order to reconstruct horizontal lines.
		pagination.measuredGroup(
			fill,
			CGSize(width: 65, height: 30),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: true
		)
		pagination.measuredGroup(
			intrinsic,
			CGSize(width: 35, height: 60),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: false
		)
		pagination.measuredGroup(
			nextLine,
			CGSize(width: 100, height: 35),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: true
		)

		// Money + Valuables are one 60-point line; the next line is 35 points.
		// If measurement order were used, they would incorrectly consume 125.
		#expect(pagination.pageNumber == 1)
	}

	@Test("Rendering applies content inset without reapplying page margin")
	func renderingPreservesX() {
		let pagination = Pagination(
			layout: .init(
				pageSize: .custom(width: 120, height: 100),
				margins: .init(left: 12, right: 8, top: 0, bottom: 0)
			),
			insets: .init(left: 7, right: 0, top: 0, bottom: 0)
		)
		#expect(pagination.printableRect.origin.x == 12)
		#expect(pagination.contentRect.origin.x == 19)

		let first = pagination.registerGroup(sectionID: "first")
		let second = pagination.registerGroup(sectionID: "second")

		pagination.measuredGroup(
			first,
			CGSize(width: 35, height: 20),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: false
		)
		pagination.measuredGroup(
			second,
			CGSize(width: 65, height: 20),
			behavior: .flow,
			spacingBefore: 0,
			terminatesLine: true
		)

		// Grid origins are already based at printableRect.origin.x.
		// Pagination adds only the content inset (19 - 12 = 7).
		let firstOrigin = pagination.renderingGroup(first, frame: CGRect(origin: CGPoint(x: 22, y: 0), size: CGSize(width: 35, height: 20)))
		let secondOrigin = pagination.renderingGroup(second, frame: CGRect(origin: CGPoint(x: 57, y: 0), size: CGSize(width: 65, height: 20)))
		#expect(firstOrigin.x == 29)
		#expect(secondOrigin.x == 64)
		#expect(secondOrigin.x - firstOrigin.x == 35)
		#expect(pagination.positions["first"]?.pageIndex == 0)
		#expect(pagination.positions["first"]?.frame.origin == firstOrigin)
		#expect(pagination.positions["first"]?.pageRect == pagination.pageRect)
	}

}
