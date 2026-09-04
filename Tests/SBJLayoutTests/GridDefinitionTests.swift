import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("GridDefinition")
struct GridDefinitionTests {
	private final class Element: TrackElement {
		let size: CGSize

		init(_ size: CGSize = .zero) {
			self.size = size
		}

		func measure(bounds: CGSize) -> CGSize {
			size
		}
	}

	private func resolvedDefinition(
		columns columnTracks: [Track] = [
			Track(.fixed(20), align: .left, gap: 5),
			Track(.fixed(30), align: .right, gap: 7)
		],
		rows rowFactory: TrackFactory = .init(
			row: Track(.fixed(10), align: .bottom, gap: 3),
			minCount: 2,
			maxCount: 2,
		),
		cells: [Element]? = nil,
		layout: TrackArrangement = .gaps
	) -> GridDefinition<Element> {
		let cells = cells ?? (0..<4).map {
			Element(CGSize(width: CGFloat($0 + 1), height: CGFloat($0 + 2)))
		}
		let definition = GridDefinition(
			columns: .init(columnTracks),
			rows: rowFactory,
			cells: cells,
			arrangement: layout
		)

		return definition.resolving(
			bounds: CGSize(width: 55, height: 23),
			columns: TrackMetrics(
				tracks: columnTracks,
				lengths: [20, 30],
				offsets: [0, 25],
				size: 55
			),
			rows: TrackMetrics(
				tracks: (0..<2).map(rowFactory.def),
				lengths: [10, 10],
				offsets: [0, 13],
				size: 23
			),
			measured: cells.map(\.size)
		)
	}

	@Test("Initial definition contains immutable specification and unresolved snapshot")
	func initialDefinitionState() {
		let cells = (0..<3).map { _ in Element() }
		let rows = TrackFactory(
			row: Track(.intrinsic()),
			minCount: 1,
			maxCount: 4)
		let columns = TrackFactory(
			[Track(.fixed(10)), Track(.fill())]
		)
		let definition = GridDefinition(
			columns: columns,
			rows: rows,
			cells: cells,
			arrangement: .tight
		)

		#expect(definition.columnFactory.maxCount - definition.columnFactory.minCount + 1 == 2)
		#expect(definition.cells.count == 3)
		#expect(definition.arrangement == .tight)
		#expect(definition.columns.tracks.isEmpty)
		#expect(definition.columns.lengths.isEmpty)
		#expect(definition.rows.tracks.isEmpty)
		#expect(definition.measured == [.zero, .zero, .zero])
		#expect(definition.bounds == nil)
	}

	@Test("Row and cell counts derive from immutable specification")
	func derivedCounts() {
		let cells = (0..<5).map { _ in Element() }
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1))]),
			rows: .init(row: Track(.fixed(1)), minCount: 1, maxCount: 2),
			cells: cells,
			arrangement: .tight
		)

		#expect(definition.columnCount == 2)
		#expect(definition.wantedRowCount == 3)
		#expect(definition.rowCount == 2)
		#expect(definition.cellCount == 4)
		#expect(!definition.isEmpty)
	}

	@Test("Minimum rows may create empty trailing rows")
	func minimumRowsCreateEmptyRows() {
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1))]),
			rows: .init(row: Track(.fixed(1)), minCount: 3, maxCount: 5),
			cells: [Element()],
			arrangement: .tight
		)

		#expect(definition.wantedRowCount == 1)
		#expect(definition.rowCount == 3)
		#expect(definition.cellCount == 1)
	}

	@Test("Empty columns produce an empty definition")
	func emptyColumns() {
		let definition = GridDefinition(
			columns: .init([]),
			cells: [Element()],
			arrangement: .tight
		)

		#expect(definition.columnCount == 0)
		#expect(definition.wantedRowCount == 0)
		#expect(definition.rowCount == 0)
		#expect(definition.cellCount == 0)
		#expect(definition.isEmpty)
	}

	@Test("A zero maximum row count excludes every cell")
	func zeroMaximumRows() {
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1))]),
			rows: .init(row: Track(.fixed(1)), minCount: 0, maxCount: 0),
			cells: [Element()],
			arrangement: .tight
		)

		#expect(definition.rowCount == 0)
		#expect(definition.cellCount == 0)
		#expect(definition.isEmpty)
	}

	@Test("Resolving creates a new snapshot without changing the original")
	func resolvingCreatesNewSnapshot() {
		let cell = Element(CGSize(width: 8, height: 9))
		let original = GridDefinition(
			columns: .init([Track(.fixed(20))]),
			cells: [cell],
			arrangement: .tight
		)
		let resolved = original.resolving(
			bounds: CGSize(width: 20, height: 9),
			columns: TrackMetrics(
				tracks: (0..<original.columnCount).map(original.columnFactory.def),
				lengths: [20],
				offsets: [0],
				size: 20
			),
			rows: TrackMetrics(
				tracks: [Track(.fixed(9))],
				lengths: [9],
				offsets: [0],
				size: 9
			),
			measured: [cell.size]
		)

		#expect(original.bounds == nil)
		#expect(original.size == .zero)
		#expect(original.measured == [.zero])

		#expect(resolved.bounds == CGSize(width: 20, height: 9))
		#expect(resolved.size == CGSize(width: 20, height: 9))
		#expect(resolved.measured == [cell.size])
		#expect(resolved.cells[0] === cell)
	}

	@Test("Cell indexing and lookup are row-major and respect the visible cell count")
	func cellIndexingAndLookup() {
		let cells = (0..<5).map { _ in Element() }
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1))]),
			rows: .init(row: Track(.fixed(1)), minCount: 0, maxCount: 2),
			cells: cells,
			arrangement: .tight
		)

		#expect(definition.cellIdx(0, 0) == 0)
		#expect(definition.cellIdx(1, 0) == 1)
		#expect(definition.cellIdx(0, 1) == 2)
		#expect(definition.cellIdx(1, 1) == 3)
		#expect(definition.cell(at: 0) === cells[0])
		#expect(definition.cell(at: 3) === cells[3])
		#expect(definition.cell(at: 4) == nil)
		#expect(definition.cell(at: -1) == nil)
	}

	@Test("Measured lookup respects the visible cell count")
	func measuredLookup() {
		let cells = (0..<3).map { _ in Element() }
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1))]),
			rows: .init(row: Track(.fixed(1)), minCount: 0, maxCount: 1),
			cells: cells,
			arrangement: .tight
		).resolving(
			bounds: CGSize(width: 2, height: 1),
			columns: TrackMetrics(
				tracks: [Track(.fixed(1)), Track(.fixed(1))],
				lengths: [1, 1],
				offsets: [0, 1],
				size: 2
			),
			rows: TrackMetrics(
				tracks: [Track(.fixed(1))],
				lengths: [1],
				offsets: [0],
				size: 1
			),
			measured: [
				CGSize(width: 1, height: 2),
				CGSize(width: 3, height: 4),
				CGSize(width: 5, height: 6)
			]
		)

		#expect(definition.measuredSize(at: 0) == CGSize(width: 1, height: 2))
		#expect(definition.measuredSize(at: 1) == CGSize(width: 3, height: 4))
		#expect(definition.measuredSize(at: 2) == nil)
		#expect(definition.measuredSize(at: -1) == nil)
	}

	@Test("Column traversal visits only existing visible cells")
	func columnTraversal() {
		let cells = (0..<5).map { _ in Element() }
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1))]),
			cells: cells,
			arrangement: .tight
		)
		var firstColumn: [Int] = []
		var secondColumn: [Int] = []
		var invalidColumn: [Int] = []

		definition.forEachCell(inColumn: 0) { firstColumn.append($0) }
		definition.forEachCell(inColumn: 1) { secondColumn.append($0) }
		definition.forEachCell(inColumn: 2) { invalidColumn.append($0) }

		#expect(firstColumn == [0, 2, 4])
		#expect(secondColumn == [1, 3])
		#expect(invalidColumn.isEmpty)
	}

	@Test("Row traversal visits only existing visible cells")
	func rowTraversal() {
		let cells = (0..<5).map { _ in Element() }
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1)), Track(.fixed(1))]),
			cells: cells,
			arrangement: .tight
		)
		var firstRow: [Int] = []
		var secondRow: [Int] = []
		var invalidRow: [Int] = []

		definition.forEachCell(inRow: 0) { firstRow.append($0) }
		definition.forEachCell(inRow: 1) { secondRow.append($0) }
		definition.forEachCell(inRow: 2) { invalidRow.append($0) }

		#expect(firstRow == [0, 1, 2])
		#expect(secondRow == [3, 4])
		#expect(invalidRow.isEmpty)
	}

	@Test("Allocated rectangles use resolved offsets and supplied origin")
	func allocatedRectangles() {
		let definition = resolvedDefinition()
		let origin = CGPoint(x: 100, y: 200)

		#expect(
			definition.allocatedRect(origin, column: 1)
				== CGRect(x: 125, y: 200, width: 30, height: 23)
		)
		#expect(
			definition.allocatedRect(origin, row: 1)
				== CGRect(x: 100, y: 213, width: 55, height: 10)
		)
		#expect(
			definition.allocatedRect(origin, column: 1, row: 1)
				== CGRect(x: 125, y: 213, width: 30, height: 10)
		)
	}

	@Test("Iteration emits complete immutable definition state")
	func iterationMetadata() {
		let definition = resolvedDefinition()
		var columns: [GridDefinition<Element>.ColumnIteration] = []
		var rows: [GridDefinition<Element>.RowIteration] = []
		var cells: [GridDefinition<Element>.CellIteration] = []

		definition.iterate(
			allocated: CGRect(x: 100, y: 200, width: 500, height: 500),
			column: { columns.append($0) },
			row: { rows.append($0) },
			cell: { cells.append($0) }
		)

		#expect(columns.map(\.index) == [0, 1])
		#expect(rows.map(\.index) == [0, 1])
		#expect(cells.map(\.i) == [0, 1, 2, 3])
		#expect(cells.map(\.c) == [0, 1, 0, 1])
		#expect(cells.map(\.r) == [0, 0, 1, 1])
		#expect(cells.map(\.content) == definition.measured.map(Optional.some))
		#expect(cells[0].alignment == [.left, .bottom])
		#expect(cells[1].alignment == [.right, .bottom])
		#expect(cells[0].definition.bounds == definition.bounds)
		#expect(cells[0].definition.size == definition.size)
	}

	@Test("Iteration reports nil for an empty trailing grid cell")
	func iterationEmptyTrailingCell() {
		let cells = (0..<3).map { _ in Element(CGSize(width: 5, height: 8)) }
		let definition = resolvedDefinition(cells: cells)
		var iterations: [GridDefinition<Element>.CellIteration] = []

		definition.iterate { iterations.append($0) }

		#expect(iterations.map(\.i) == [0, 1, 2, 3])
		#expect(iterations[0].cell === cells[0])
		#expect(iterations[1].cell === cells[1])
		#expect(iterations[2].cell === cells[2])
		#expect(iterations[3].cell == nil)
		#expect(iterations[3].content == nil)
	}

	@Test("Truncation requires the complete track rectangle to fit")
	func iterationTruncation() {
		let definition = resolvedDefinition()
		var truncatedColumns: [Int] = []
		var truncatedCells: [Int] = []
		var partialColumns: [Int] = []
		var partialCells: [Int] = []
		let allocated = CGRect(x: 0, y: 0, width: 40, height: 20)

		definition.iterate(
			allocated: allocated,
			truncate: true,
			column: { truncatedColumns.append($0.index) },
			cell: { truncatedCells.append($0.i) }
		)
		definition.iterate(
			allocated: allocated,
			truncate: false,
			column: { partialColumns.append($0.index) },
			cell: { partialCells.append($0.i) }
		)

		#expect(truncatedColumns == [0])
		#expect(truncatedCells == [0])
		#expect(partialColumns == [0, 1])
		#expect(partialCells == [0, 1, 2, 3])
	}


	@Test("Vertical truncation requires the complete row rectangle to fit")
	func verticalIterationTruncation() {
		let definition = resolvedDefinition()
		var rows: [Int] = []
		var cells: [Int] = []

		definition.iterate(
			allocated: CGRect(x: 0, y: 0, width: 55, height: 18),
			truncate: true,
			row: { rows.append($0.index) },
			cell: { cells.append($0.i) }
		)

		#expect(rows == [0])
		#expect(cells == [0, 1])
	}

	@Test("Iteration skips zero-sized tracks and cells")
	func iterationSkipsZeroSizedTracks() {
		let columnTracks = [
			Track(.fixed(20)),
			Track(.fixed(0)),
			Track(.fixed(30))
		]
		let rowFactory = TrackFactory(
			minCount: 2,
			maxCount: 2,
			def: { index in
				index == 0 ? Track(.fixed(10)) : Track(.fixed(0))
			}
		)
		let cells = (0..<6).map { _ in Element(CGSize(width: 5, height: 5)) }
		let definition = GridDefinition(
			columns: .init(columnTracks),
			rows: rowFactory,
			cells: cells,
			arrangement: .tight
		).resolving(
			bounds: CGSize(width: 50, height: 10),
			columns: TrackMetrics(
				tracks: columnTracks,
				lengths: [20, 0, 30],
				offsets: [0, 20, 20],
				size: 50
			),
			rows: TrackMetrics(
				tracks: (0..<2).map(rowFactory.def),
				lengths: [10, 0],
				offsets: [0, 10],
				size: 10
			),
			measured: cells.map(\.size)
		)

		var columns: [Int] = []
		var rows: [Int] = []
		var cellIndexes: [Int] = []

		definition.iterate(
			column: { columns.append($0.index) },
			row: { rows.append($0.index) },
			cell: { cellIndexes.append($0.i) }
		)

		#expect(columns == [0, 2])
		#expect(rows == [0])
		#expect(cellIndexes == [0, 2])
	}

	@Test("Cell traversal ignores negative row and column indexes")
	func negativeTraversalIndexesAreIgnored() {
		let definition = GridDefinition(
			columns: .init([Track(.fixed(1)), Track(.fixed(1))]),
			cells: [Element(), Element()],
			arrangement: .tight
		)
		var indexes: [Int] = []

		definition.forEachCell(inColumn: -1) { indexes.append($0) }
		definition.forEachCell(inRow: -1) { indexes.append($0) }

		#expect(indexes.isEmpty)
	}
}
