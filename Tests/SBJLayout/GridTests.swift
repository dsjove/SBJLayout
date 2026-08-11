import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Grid rendering")
struct GridRenderingTests {
	private final class DrawingElement: Renderable {
		struct DrawCall {
			let allocated: CGRect
			let measured: CGSize
			let alignment: Alignment
		}

		let size: CGSize
		private(set) var measuredBounds: [CGSize] = []
		private(set) var drawCalls: [DrawCall] = []

		init(size: CGSize) {
			self.size = size
		}

		func measure(bounds: CGSize) -> CGSize {
			measuredBounds.append(bounds)
			return size
		}

		func draw(
			in allocated: CGRect,
			measured: CGSize,
			align: Alignment
		) {
			drawCalls.append(.init(
				allocated: allocated,
				measured: measured,
				alignment: align
			))
		}
	}

	@Test("Default cell renderer draws the cell")
	func defaultCellRendererDrawsCell() {
		let cell = DrawingElement(size: CGSize(width: 12, height: 8))
		let grid = Grid(
			cols: .init([Track(.fixed(40), align: .right)]),
			rows: TrackFactory(row: Track(.fixed(20), align: .bottom)),
			arrangement: .tight,
			cells: [cell]
		)

		grid.draw(
			in: CGRect(x: 10, y: 20, width: 40, height: 20),
			measured: CGSize(width: 40, height: 20),
			align: .leftTop
		)

		#expect(cell.drawCalls.count == 1)
		#expect(cell.drawCalls[0].allocated == CGRect(x: 10, y: 20, width: 40, height: 20))
		#expect(cell.drawCalls[0].measured == CGSize(width: 12, height: 8))
		#expect(cell.drawCalls[0].alignment == [.right, .bottom])
	}

	@Test("Grid alignment positions the complete rendered grid")
	func gridAlignmentPositionsRenderedGrid() {
		let cell = DrawingElement(size: CGSize(width: 10, height: 10))
		let grid = Grid(
			cols: .init([Track(.fixed(50))]),
			rows: TrackFactory(row: Track(.fixed(20))),
			arrangement: .tight,
			cells: [cell]
		)

		grid.draw(
			in: CGRect(x: 10, y: 20, width: 100, height: 80),
			measured: CGSize(width: 50, height: 20),
			align: [.centerX, .centerY]
		)

		#expect(cell.drawCalls.count == 1)
		#expect(cell.drawCalls[0].allocated == CGRect(x: 35, y: 50, width: 50, height: 20))
	}

	@Test("Custom render callbacks receive positioned iteration records")
	func customRenderCallbacksReceivePositionedRecords() {
		let cells = [
			DrawingElement(size: CGSize(width: 5, height: 6)),
			DrawingElement(size: CGSize(width: 7, height: 8))
		]

		var columns: [Grid.ColumnIteration] = []
		var rows: [Grid.RowIteration] = []
		var renderedCells: [Grid.CellIteration] = []

		let grid = Grid(
			cols: .init([
				Track(.fixed(20), gap: 5),
				Track(.fixed(30))
			]),
			rows: TrackFactory(row: Track(.fixed(10))),
			render: .init(
				column: { columns.append($0) },
				row: { rows.append($0) },
				cell: { renderedCells.append($0) }
			),
			arrangement: .gaps,
			cells: cells
		)

		grid.draw(
			in: CGRect(x: 100, y: 200, width: 55, height: 10),
			measured: CGSize(width: 55, height: 10),
			align: .leftTop
		)

		#expect(columns.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 20, height: 10),
			CGRect(x: 125, y: 200, width: 30, height: 10)
		])
		#expect(rows.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 55, height: 10)
		])
		#expect(renderedCells.map(\.rect) == [
			CGRect(x: 100, y: 200, width: 20, height: 10),
			CGRect(x: 125, y: 200, width: 30, height: 10)
		])
		#expect(renderedCells.map(\.i) == [0, 1])
	}

	@Test("Custom cell renderer replaces default drawing")
	func customCellRendererReplacesDefaultDrawing() {
		let cell = DrawingElement(size: CGSize(width: 10, height: 10))
		var rendered: [Grid.CellIteration] = []

		let grid = Grid(
			cols: .init([Track(.fixed(20))]),
			render: .init(cell: { rendered.append($0) }),
			arrangement: .tight,
			cells: [cell]
		)

		grid.draw(
			in: CGRect(x: 0, y: 0, width: 20, height: 10),
			measured: CGSize(width: 20, height: 10),
			align: .leftTop
		)

		#expect(rendered.count == 1)
		#expect(cell.drawCalls.isEmpty)
	}

	@Test("Custom cell renderer may invoke default rendering")
	func customCellRendererMayInvokeDefaultRendering() {
		let cell = DrawingElement(size: CGSize(width: 10, height: 10))
		var callbackCount = 0

		let grid = Grid(
			cols: .init([Track(.fixed(20))]),
			render: .init(cell: {
				callbackCount += 1
				$0.render()
			}),
			arrangement: .tight,
			cells: [cell]
		)

		grid.draw(
			in: CGRect(x: 5, y: 7, width: 20, height: 10),
			measured: CGSize(width: 20, height: 10),
			align: .leftTop
		)

		#expect(callbackCount == 1)
		#expect(cell.drawCalls.count == 1)
		#expect(cell.drawCalls[0].allocated == CGRect(x: 5, y: 7, width: 20, height: 10))
	}

	@Test("Drawing an empty grid emits no render callbacks")
	func emptyGridEmitsNoRenderCallbacks() {
		var columnCount = 0
		var rowCount = 0
		var cellCount = 0

		let grid = Grid(
			cols: .init([]),
			render: .init(
				column: { _ in columnCount += 1 },
				row: { _ in rowCount += 1 },
				cell: { _ in cellCount += 1 }
			),
			arrangement: .tight,
			cells: []
		)

		grid.draw(
			in: CGRect(x: 10, y: 20, width: 100, height: 100),
			measured: .zero,
			align: .leftTop
		)

		#expect(columnCount == 0)
		#expect(rowCount == 0)
		#expect(cellCount == 0)
	}
}

extension GridRenderingTests {
	@Test("Table header does not size a column whose body widths are all zero")
	func tableHeaderDoesNotSizeEmptyColumn() {
		let cells = [
			DrawingElement(size: CGSize(width: 40, height: 10)),
			DrawingElement(size: CGSize(width: 60, height: 10)),
			DrawingElement(size: CGSize(width: 20, height: 10)),
			DrawingElement(size: CGSize(width: 0, height: 10)),
			DrawingElement(size: CGSize(width: 30, height: 10)),
			DrawingElement(size: CGSize(width: 0, height: 10))
		]
		let grid = Grid(
			table: [Track(.intrinsic()), Track(.intrinsic())],
			header: Track(.intrinsic()),
			rows: TrackFactory(.intrinsic()),
			cells: { cells }
		)

		let definition = grid.layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [40, 0])
	}

	@Test("Table header participates normally when a body cell is nonzero")
	func tableHeaderParticipatesWhenColumnHasContent() {
		let cells = [
			DrawingElement(size: CGSize(width: 60, height: 10)),
			DrawingElement(size: CGSize(width: 0, height: 10)),
			DrawingElement(size: CGSize(width: 25, height: 10))
		]
		let grid = Grid(
			table: [Track(.intrinsic())],
			header: Track(.intrinsic()),
			rows: TrackFactory(.intrinsic()),
			cells: { cells }
		)

		let definition = grid.layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [60])
	}

	@Test("Table header preserves the column's custom aggregate")
	func tableHeaderPreservesCustomColumnAggregate() {
		let column = Track(
			.intrinsic(),
			aggregate: { $0.reduce(0, +) }
		)
		let cells = [
			DrawingElement(size: CGSize(width: 50, height: 10)),
			DrawingElement(size: CGSize(width: 10, height: 10)),
			DrawingElement(size: CGSize(width: 20, height: 10))
		]
		let grid = Grid(
			table: [column],
			header: Track(.intrinsic()),
			rows: TrackFactory(.intrinsic()),
			cells: { cells }
		)

		let definition = grid.layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [80])
	}

	@Test("Table leader does not size a row whose remaining heights are all zero")
	func tableLeaderDoesNotSizeEmptyRow() {
		let cells = [
			DrawingElement(size: CGSize(width: 10, height: 30)),
			DrawingElement(size: CGSize(width: 10, height: 0)),
			DrawingElement(size: CGSize(width: 10, height: 0)),
			DrawingElement(size: CGSize(width: 10, height: 40)),
			DrawingElement(size: CGSize(width: 10, height: 12)),
			DrawingElement(size: CGSize(width: 10, height: 18))
		]
		let grid = Grid(
			table: [Track(.intrinsic()), Track(.intrinsic())],
			leader: Track(.intrinsic()),
			rows: TrackFactory(.intrinsic()),
			cells: { cells }
		)

		let definition = grid.layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [0, 40])
	}

	@Test("Table leader participates normally when another cell in the row is nonzero")
	func tableLeaderParticipatesWhenRowHasContent() {
		let cells = [
			DrawingElement(size: CGSize(width: 10, height: 40)),
			DrawingElement(size: CGSize(width: 10, height: 12)),
			DrawingElement(size: CGSize(width: 10, height: 18))
		]
		let grid = Grid(
			table: [Track(.intrinsic()), Track(.intrinsic())],
			leader: Track(.intrinsic()),
			rows: TrackFactory(.intrinsic()),
			cells: { cells }
		)

		let definition = grid.layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [40])
	}
}

