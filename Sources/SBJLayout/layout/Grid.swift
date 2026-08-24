import CoreGraphics
// TODO: Feature - Pagination policies
// TODO: Feature - Pivot Table
// TODO: Feature - Wrapping header duplication?
// TODO: Feature - identifiable reducers and groupings for uniform Tracks
// TODO: Feature - draw placeholder tracks to bounded edge (like min track)

// Custom Columns Features Remaining ...
// TODO: Feature - Track Spans
// TODO: Feature - cross grid sizing sync
// TODO: Feature - dynamic gaps that fill (like SwiftUI spacer)
// TODO: Feature - 'best fit' intrinsic size (allow 3, algorithm TBD)
// TODO: Feature - lexical alignment across cells

//Some cells will draw this debug rect not reorigined with page
nonisolated(unsafe) internal var drawCells = false
nonisolated(unsafe) internal var drawAllocated = false

/*
Custom Columns features not in scope...

Dynamic live large sets of data
1) Cell needs to become hashable so we can effectly detect content changes for remeasuring
2) Cell needs to become identifiable so we can track movement (sorting, column mapping, adding, removing)
3) Cells on init should become a factory like cols and rows
4) Then we need to detect if the change requires invalidating measurements or just redraw
5) The changes need to be additive and throttled to a f/s

Sticky Columns (easily done today and may have use)
1) GridLayout would need to know scroll position
2) Iteration would have to be aware of -1 origin
3) Track would need bool

Split tables
1) This would require a design change of 'origin groupings'
*/

public extension Grid {
//MARK: Convenience inits
	init(
		horzFlow col: Column, wrapped at: Int? = nil,
		rows: Rows = .init(align: .left),
		@RenderableBuilder cells: ()->Cells,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let cells = cells()
		self.init(
			cols: .init(Array(repeating: col, count: at ?? cells.count)),
			rows: rows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			cells: cells)
	}

	init(
		vertFlow col: Column,
		rows: Rows = .init(align: .centerY),
		@RenderableBuilder cells: ()->Cells,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let cells = cells()
		self.init(
			cols: .init(col: col),
			rows: rows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			cells: cells)
	}

	init(
		table cols: [Column], columnMap: ((Int)->Int)? = nil,
		header: Track? = nil,
		leader: Track? = nil,
		rows: TrackFactory = .init(),
		@RenderableBuilder cells: ()->Cells,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let cells = cells()

		let tableColumns: [Column] = {
			let columns = if let leader {
				[leader] + cols
			} else {
				cols
			}
			guard header != nil else { return columns }
			return columns.map { column in
				let aggregate = column.aggregate
				return Track(column) { candidates in
					guard candidates.dropFirst().contains(where: { $0 > 0 }) else {
						return nil
					}
					return aggregate(candidates)
				}
			}
		}()

		let tableRows = TrackFactory(
			minCount: rows.minCount,
			maxCount: rows.maxCount
		) { index in
			let row = if let header, index == 0 {
				header
			} else {
				rows.def(index)
			}
			guard leader != nil else { return row }
			let aggregate = row.aggregate
			return Track(row) { candidates in
				guard candidates.dropFirst().contains(where: { $0 > 0 }) else {
					return nil
				}
				return aggregate(candidates)
			}
		}

		self.init(
			cols: .init(tableColumns, map: columnMap),
			rows: tableRows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			cells: cells)
	}
}

public extension GridDefinition<TrackedElement>.CellIteration {
	func render() {
		cell?.element.render(in: rect, measured: content, align: alignment)
if drawCells {
	JCSRect(stroke: .red , lineWidth: 0.5).draw(in: rect)
}
	}
}

public struct Grid: Renderable {
//MARK: Types
	public typealias Layout = GridLayout<TrackedElement>
	public typealias Definition = GridDefinition<TrackedElement>
	public typealias Column = Track
	public typealias Columns = TrackFactory
	public typealias Row = Track
	public typealias Rows = TrackFactory
	public typealias Cell = Renderable
	public typealias Cells = [Renderable]

	public typealias ColumnIteration = Definition.ColumnIteration
	public typealias RowIteration = Definition.RowIteration
	public typealias CellIteration = Definition.CellIteration

	public struct Render {
		public let column: ((ColumnIteration)->())?
		public let row: ((RowIteration)->())?
		public let cell: (CellIteration)->()

		public init(
			column: ((ColumnIteration) -> ())? = nil,
			row: ((RowIteration) -> ())? = nil,
			cell: ((CellIteration) -> ())? = nil
		) {
			self.column = column
			self.row = row
			self.cell = {
				if let cell { cell($0) } else { $0.render() }
			}
		}
	}

//MARK: Inits
	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		arrangement: TrackArrangement = .gaps,
		wrapping: GridWrapping = .none,
		@RenderableBuilder cells: ()->Cells
	) {
		self.init(
			cols: cols,
			rows: rows,
			render: render,
			arrangement: arrangement,
			wrapping: wrapping,
			cells: cells())
	}

	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		arrangement: TrackArrangement = .gaps,
		wrapping: GridWrapping = .none,
		cells: Cells
	) {
		self.render = render
		self.layout = .init(
			columns: cols,
			rows: rows,
			cells: cells.map(TrackedElement.init),
			arrangement: arrangement,
			wrapping: wrapping)
	}

	public private(set) var id: String = ""

	public func id(_ id: String) -> Self {
		var copy = self
		copy.id = id
		return copy
	}

//MARK: API
	public let layout: Layout
	public let render: Render

	public func measure(bounds: CGSize) -> CGSize {
		let definition = layout.measure(bounds: bounds)
		return definition.size
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		let definition = layout.resolvedDefinition(for: measured)
		let positioned = align.apply(size: definition.size, in: allocated)
if drawAllocated {
	JCSRect(stroke: .blue.withAlphaComponent(0.5) , lineWidth: 1.5).draw(in: positioned)
}
		definition.iterate(
			allocated: positioned,
			column: render.column,
			row: render.row,
			cell: render.cell
		)
	}
}
