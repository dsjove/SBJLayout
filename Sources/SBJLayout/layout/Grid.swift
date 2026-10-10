import CoreGraphics
import Foundation
// TODO: Feature - Automatic pagination at complete wrapped-row boundaries.
// Today, PaginationGroup directives in the builder are the only source of break
// permission. When wrapping creates a new *physical* row, Grid could emit an
// implicit .flow boundary before that whole row. Use the same logical event
// representation as explicit PaginationGroups; do not invent coordinate hints,
// split a row's cells, or silently change content grouping.
// TODO: Feature - Pivot Table
// TODO: Feature - Wrapping header duplication?
// TODO: Feature - identifiable reducers and groupings for uniform Tracks
// TODO: Feature - draw placeholder tracks to bounded edge (like min track)
// TODO: Feature - dynamic gaps that fill (like SwiftUI spacer)

// 'Custom Columns' In-Scope Features Remaining...
// TODO: Feature - Track Spans
// TODO: Feature - 'best fit' intrinsic size (allow 3, algorithm TBD)
// TODO: Feature - lexical alignment across cells

/*
'Custom Columns' features not in scope...

Dynamic live large sets of data ('Grid' is not a UI solution)
1) Cell needs to become hashable so we can effectly detect content changes for remeasuring
2) Cell needs to become identifiable so we can track movement
3) Cells on init should become a factory like cols and rows
4) Then we need to detect if the change requires invalidating measurements or just redraw
5) The changes need to be additive and throttled to a f/s
6) Column-Mapping/Row-Sort view-model and size caching

Sticky Columns (only useful for UI content scrolling)
1) GridLayout would need to know scroll position
2) Iteration would have to be aware of -1 origin
3) Track would need bool

Split tables (only useful for UI content scrolling)
1) This would require a design change of 'origin groupings'
2) or cross grid sizing/pos sync
*/

//Some cells will draw this debug rect not reorigined on new page
nonisolated(unsafe) internal var debugDrawCells = false
nonisolated(unsafe) internal var debugDrawAllocated = false

public extension Grid {
//MARK: Convenience inits
	init(
		horzFlow col: Column, wrapped at: Int? = nil,
		rows: Rows = .init(align: .left),
		@RenderableBuilder cells: ()->Renderables,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let content = cells()
		self.init(
			cols: .init(Array(repeating: col, count: at ?? content.content.count)),
			rows: rows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
            content: content)
	}

	init(
		vertFlow col: Column,
		rows: Rows = .init(align: .centerY),
		@RenderableBuilder cells: ()->Renderables,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let content = cells()
		self.init(
			cols: .init(col: col),
			rows: rows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			content: content)
	}

	init(
		table cols: [Column], columnMap: ((Int)->Int)? = nil,
		header: Track? = nil,
		leader: Track? = nil,
		rows: TrackFactory = .init(),
		@RenderableBuilder cells: ()->Renderables,
		colRender: ((ColumnIteration)->())? = nil,
		rowRender: ((RowIteration)->())? = nil,
		cellRender: ((CellIteration)->())? = nil
	) {
		let content = cells()

		let tableColumnsUnmapped: [Column] = {
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

		let tableColumns = tableColumnsUnmapped.indices.map { tableColumnsUnmapped[columnMap?($0) ?? $0] }

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
			cols: .init(tableColumns.enumerated().filter { $0.element.role == .normal }.map { $0.element }, map: nil),
			rows: tableRows,
			render: .init(column: colRender, row: rowRender, cell: cellRender),
			accessories: tableColumns.indices.filter { tableColumns[$0].role.isAccessory }.map { index in
				.init(inputStride: tableColumns.count, slot: index, track: tableColumns[index], physicalSlots: tableColumns.indices.filter { tableColumns[$0].role == .normal })
			},
			content: content)
	}
}

public extension GridDefinition<TrackedElement>.CellIteration {
	func render() {
		cell?.element.render(in: rect, measured: content, align: alignment)
if debugDrawCells {
	JCSRect(stroke: .red , lineWidth: 0.5).draw(in: rect)
}
	}
}

public struct Grid: Renderable, PaginationTraversable {
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
		wrapping: TrackAxis? = nil,
		accessories: [Definition.RowAccessory] = [],
		@RenderableBuilder cells: ()->Renderables
	) {
		self.init(
			cols: cols,
			rows: rows,
			render: render,
			arrangement: arrangement,
			wrapping: wrapping,
			accessories: accessories,
			content: cells())
	}

    private init(
		cols: Columns,
		rows: Rows,
		render: Render,
		arrangement: TrackArrangement = .gaps,
		wrapping: TrackAxis? = nil,
		accessories: [Definition.RowAccessory] = [],
		content: Renderables
	) {
		self.init(
			cols: cols, rows: rows, render: render,
			arrangement: arrangement, wrapping: wrapping,
			accessories: accessories, flattened: FlattenedPaginationContent(content))
	}

	public init(
		cols: Columns,
		rows: Rows = .init(),
		render: Render = .init(),
		arrangement: TrackArrangement = .gaps,
		wrapping: TrackAxis? = nil,
		accessories: [Definition.RowAccessory] = [],
		cells: Cells
	) {
		self.init(cols: cols, rows: rows, render: render,
			arrangement: arrangement, wrapping: wrapping,
			accessories: accessories, flattened: FlattenedPaginationContent(
			Renderables(cells.map { .content($0) })))
	}

	private init(
		cols: Columns,
		rows: Rows,
		render: Render,
		arrangement: TrackArrangement,
		wrapping: TrackAxis?,
		accessories: [Definition.RowAccessory],
		flattened: FlattenedPaginationContent
	) {
		self.render = render
		self.paginationID = UUID()
		self.paginationContent = flattened
		let trackedCells = flattened.cells.map(TrackedElement.init)
		self.layout = .init(
			columns: cols,
			rows: rows,
			cells: trackedCells,
			arrangement: arrangement,
			wrapping: wrapping,
			accessories: accessories)
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
	let paginationID: UUID
	let paginationContent: FlattenedPaginationContent

	var hasPaginationGroups: Bool {
		paginationContent.hasGroups || paginationContent.cells.contains {
			($0 as? any PaginationTraversable)?.hasPaginationGroups == true
		}
	}

	func collectPaginationEvents(
		in allocated: CGRect, measured: CGSize, align: Alignment,
		into events: inout [PaginationEvent]
	) {
		RenderableEnvironment.context.pagination.collectEvents(
			from: self, in: allocated, measured: measured, align: align, into: &events)
	}

	public func measure(bounds: CGSize) -> CGSize {
		let definition = layout.measure(bounds: bounds)
		return definition.size
	}

	public func minimumMeasure(bounds: CGSize) -> CGSize {
		layout.minimumMeasure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		let definition = layout.resolvedDefinition(for: measured)
		let positioned = align.apply(size: definition.size, in: allocated)
if debugDrawAllocated {
	JCSRect(stroke: .blue.withAlphaComponent(0.5) , lineWidth: 1.5).draw(in: positioned)
}
		RenderableEnvironment.context.pagination.renderGrid(
			self, definition: definition, positioned: positioned)
	}
}
