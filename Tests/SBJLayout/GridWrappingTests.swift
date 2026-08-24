import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Grid wrapping")
struct GridWrappingTests {
	private final class Element: TrackElement {
		let size: CGSize
		private(set) var measuredBounds: [CGSize] = []

		init(_ width: CGFloat = 1, _ height: CGFloat = 1) {
			self.size = CGSize(width: width, height: height)
		}

		func measure(bounds: CGSize) -> CGSize {
			measuredBounds.append(bounds)
			return size
		}
	}

	@Test("Vertical wrapping resets row Y and advances by grid width")
	func verticalWrappingGeometry() {
		let cells = (0..<8).map { _ in Element() }
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(20)),
				Track(.fixed(30))
			]),
			rows: .init(row: Track(.fixed(30))),
			cells: cells,
			arrangement: .tight,
			wrapping: .vertical
		)

		let definition = layout.measure(bounds: CGSize(width: 200, height: 70))
		#expect(definition.size == CGSize(width: 100, height: 60))
		#expect(definition.allocatedRect(column: 0, row: 0) == CGRect(x: 0, y: 0, width: 20, height: 30))
		#expect(definition.allocatedRect(column: 1, row: 1) == CGRect(x: 20, y: 30, width: 30, height: 30))
		#expect(definition.allocatedRect(column: 0, row: 2) == CGRect(x: 50, y: 0, width: 20, height: 30))
		#expect(definition.allocatedRect(column: 1, row: 3) == CGRect(x: 70, y: 30, width: 30, height: 30))

		var iterations: [GridDefinition<Element>.CellIteration] = []
		definition.iterate(cell: { iterations.append($0) })
		#expect(iterations.map(\.i) == Array(0..<8))
		#expect(iterations.map(\.c) == [0, 1, 0, 1, 0, 1, 0, 1])
		#expect(iterations.map(\.r) == [0, 0, 1, 1, 2, 2, 3, 3])
	}

	@Test("Horizontal wrapping resets column X and advances by grid height")
	func horizontalWrappingGeometry() {
		let cells = (0..<8).map { _ in Element() }
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(30)),
				Track(.fixed(30)),
				Track(.fixed(30)),
				Track(.fixed(30))
			]),
			rows: .init(row: Track(.fixed(10))),
			cells: cells,
			arrangement: .tight,
			wrapping: .horizontal
		)

		let definition = layout.measure(bounds: CGSize(width: 70, height: 200))
		#expect(definition.size == CGSize(width: 60, height: 40))
		#expect(definition.allocatedRect(column: 0, row: 0) == CGRect(x: 0, y: 0, width: 30, height: 10))
		#expect(definition.allocatedRect(column: 1, row: 1) == CGRect(x: 30, y: 10, width: 30, height: 10))
		#expect(definition.allocatedRect(column: 2, row: 0) == CGRect(x: 0, y: 20, width: 30, height: 10))
		#expect(definition.allocatedRect(column: 3, row: 1) == CGRect(x: 30, y: 30, width: 30, height: 10))
	}

	@Test("Unbounded primary dimension disables wrapping")
	func unboundedDoesNotWrap() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(30)),
				Track(.fixed(30)),
				Track(.fixed(30)),
				Track(.fixed(30))
			]),
			rows: .init(row: Track(.fixed(10))),
			cells: (0..<4).map { _ in Element() },
			arrangement: .tight,
			wrapping: .horizontal
		)

		let definition = layout.measure(bounds: CGSize(width: .unbounded, height: 200))
		#expect(definition.size == CGSize(width: 120, height: 10))
		#expect(definition.allocatedRect(column: 3, row: 0) == CGRect(x: 90, y: 0, width: 30, height: 10))
	}

	@Test("Fill consumes the remainder and terminates a horizontal band")
	func horizontalFillTerminatesBand() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(30)),
				Track(.fill()),
				Track(.fixed(20))
			]),
			rows: .init(row: Track(.fixed(10))),
			cells: (0..<3).map { _ in Element() },
			arrangement: .tight,
			wrapping: .horizontal
		)

		let definition = layout.measure(bounds: CGSize(width: 100, height: 200))
		#expect(definition.columns.lengths == [30, 70, 20])
		#expect(definition.size == CGSize(width: 100, height: 20))
		#expect(definition.allocatedRect(column: 1, row: 0) == CGRect(x: 30, y: 0, width: 70, height: 10))
		#expect(definition.allocatedRect(column: 2, row: 0) == CGRect(x: 0, y: 10, width: 20, height: 10))
	}

	@Test("Fill consumes the remainder and terminates a vertical band")
	func verticalFillTerminatesBand() {
		let layout = GridLayout(
			columns: .init([Track(.fixed(20))]),
			rows: .init(minCount: 0, maxCount: 3) { index in
				switch index {
				case 0: Track(.fixed(30))
				case 1: Track(.fill())
				default: Track(.fixed(20))
				}
			},
			cells: (0..<3).map { _ in Element() },
			arrangement: .tight,
			wrapping: .vertical
		)

		let definition = layout.measure(bounds: CGSize(width: 200, height: 100))
		#expect(definition.rows.lengths == [30, 70, 20])
		#expect(definition.size == CGSize(width: 40, height: 100))
		#expect(definition.allocatedRect(column: 0, row: 1) == CGRect(x: 0, y: 30, width: 20, height: 70))
		#expect(definition.allocatedRect(column: 0, row: 2) == CGRect(x: 20, y: 0, width: 20, height: 20))
	}

	@Test("A single oversized track occupies its own band")
	func oversizedTrackGetsOwnBand() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(120)),
				Track(.fixed(20))
			]),
			rows: .init(row: Track(.fixed(10))),
			cells: [Element(), Element()],
			arrangement: .tight,
			wrapping: .horizontal
		)

		let definition = layout.measure(bounds: CGSize(width: 100, height: 200))
		#expect(definition.size == CGSize(width: 120, height: 20))
		#expect(definition.allocatedRect(column: 0, row: 0) == CGRect(x: 0, y: 0, width: 120, height: 10))
		#expect(definition.allocatedRect(column: 1, row: 0) == CGRect(x: 0, y: 10, width: 20, height: 10))
	}

	@Test("Gaps participate in the wrap boundary")
	func gapsParticipateInWrapBoundary() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(40), gap: 10),
				Track(.fixed(40))
			]),
			rows: .init(row: Track(.fixed(10))),
			cells: [Element(), Element()],
			arrangement: .gaps,
			wrapping: .horizontal
		)

		let wrapped = layout.measure(bounds: CGSize(width: 85, height: 200))
		#expect(wrapped.size == CGSize(width: 40, height: 23))
		#expect(wrapped.allocatedRect(column: 1, row: 0).origin == CGPoint(x: 0, y: 13))

		let exact = layout.measure(bounds: CGSize(width: 90, height: 200))
		#expect(exact.size == CGSize(width: 90, height: 10))
		#expect(exact.allocatedRect(column: 1, row: 0).origin == CGPoint(x: 50, y: 0))
	}

	@Test("Track render callbacks receive wrapped physical segments")
	func trackCallbacksReceivePhysicalSegments() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(20)),
				Track(.fixed(30))
			]),
			rows: .init(row: Track(.fixed(30))),
			cells: (0..<8).map { _ in Element() },
			arrangement: .tight,
			wrapping: .vertical
		)
		let definition = layout.measure(bounds: CGSize(width: 200, height: 70))

		var columns: [GridDefinition<Element>.ColumnIteration] = []
		var rows: [GridDefinition<Element>.RowIteration] = []
		definition.iterate(
			column: { columns.append($0) },
			row: { rows.append($0) },
			cell: { _ in }
		)

		#expect(columns.map(\.index) == [0, 0, 1, 1])
		#expect(columns.map(\.rect) == [
			CGRect(x: 0, y: 0, width: 20, height: 60),
			CGRect(x: 50, y: 0, width: 20, height: 60),
			CGRect(x: 20, y: 0, width: 30, height: 60),
			CGRect(x: 70, y: 0, width: 30, height: 60)
		])
		#expect(rows.map(\.index) == [0, 1, 2, 3])
	}
	@Test("Horizontal wrapped bands size their rows from cells in that band")
	func horizontalBandsHaveIndependentRowHeights() {
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(40)),
				Track(.fixed(40)),
				Track(.fixed(40)),
				Track(.fixed(40))
			]),
			rows: .init(.intrinsic(), gap: 5),
			cells: [
				Element(40, 10), Element(40, 20),
				Element(40, 30), Element(40, 40)
			],
			arrangement: .gaps,
			wrapping: .horizontal
		)

		let definition = layout.measure(bounds: CGSize(width: 85, height: 200))
		#expect(definition.size == CGSize(width: 80, height: 65))
		#expect(definition.allocatedRect(column: 0, row: 0) == CGRect(x: 0, y: 0, width: 40, height: 20))
		#expect(definition.allocatedRect(column: 1, row: 0) == CGRect(x: 40, y: 0, width: 40, height: 20))
		#expect(definition.allocatedRect(column: 2, row: 0) == CGRect(x: 0, y: 25, width: 40, height: 40))
		#expect(definition.allocatedRect(column: 3, row: 0) == CGRect(x: 40, y: 25, width: 40, height: 40))
	}

}
