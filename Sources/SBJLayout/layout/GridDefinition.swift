import CoreGraphics

public struct GridDefinition<Cell: TrackElement> {
	public struct TrackIteration {
		public let definition: GridDefinition
		public let track: Track
		public let index: Int
		public let rect: CGRect
	}
	public typealias ColumnIteration = TrackIteration
	public typealias RowIteration = TrackIteration

	public struct CellIteration {
		public let definition: GridDefinition
		public let cell: Cell?
		public let c: Int
		public let r: Int
		public let i: Int
		public let rect: CGRect
		public let content: CGSize?
		public let alignment: Alignment
	}

	// Grid specification.
	public let columnFactory: TrackFactory
	public let rowFactory: TrackFactory
	public let cells: [Cell]
	public let arrangement: TrackArrangement
	public let wrapping: Axis?

	// Resolved layout snapshot.
	public let columns: TrackMetrics
	public let rows: TrackMetrics
	public let measured: [CGSize]
	public let bounds: CGSize?
	private let wrappedBands: [Int]
	private let wrappedBandSizes: [CGFloat]
	private let wrappedCrossMetrics: [TrackMetrics]
	private let wrappedCrossOffsets: [CGFloat]

	public init(
		columns: TrackFactory,
		rows: TrackFactory = .init(),
		cells: [Cell],
		arrangement: TrackArrangement = .gaps,
		wrapping: Axis? = nil
	) {
		self.init(
			columnFactory: columns,
			rowFactory: rows,
			cells: cells,
			arrangement: arrangement,
			wrapping: wrapping,
			columns: .init(),
			rows: .init(),
			measured: Array(repeating: .zero, count: cells.count),
			bounds: nil,
			wrappedBands: [],
			wrappedBandSizes: [],
			wrappedCrossMetrics: [],
			wrappedCrossOffsets: []
		)
	}

	private init(
		columnFactory: TrackFactory,
		rowFactory: TrackFactory,
		cells: [Cell],
		arrangement: TrackArrangement,
		wrapping: Axis?,
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize],
		bounds: CGSize?,
		wrappedBands: [Int],
		wrappedBandSizes: [CGFloat],
		wrappedCrossMetrics: [TrackMetrics],
		wrappedCrossOffsets: [CGFloat]
	) {
		self.columnFactory = columnFactory
		self.rowFactory = rowFactory
		self.cells = cells
		self.arrangement = arrangement
		self.wrapping = wrapping
		self.columns = columns
		self.rows = rows
		self.measured = measured
		self.bounds = bounds
		self.wrappedBands = wrappedBands
		self.wrappedBandSizes = wrappedBandSizes
		self.wrappedCrossMetrics = wrappedCrossMetrics
		self.wrappedCrossOffsets = wrappedCrossOffsets
	}

	public var columnCount: Int {
		guard columnFactory.maxCount > 0 else { return 0 }
		return columnFactory.maxCount - columnFactory.minCount + 1
	}

	public var columnLayout: TrackLayout {
		.init(
			factory: columnFactory.def,
			count: columnCount,
			layout: arrangement)
	}

	public var rowLayout: TrackLayout {
		.init(
			factory: { index in
				rowFactory.def(index < wantedRowCount ? index : TrackFactory.placeholderIndex)
			},
			count: rowCount,
			layout: arrangement)
	}

	public var wantedRowCount: Int {
		columnCount > 0 ? (cells.count + columnCount - 1) / columnCount : 0
	}

	public var rowCount: Int {
		max(0, max(rowFactory.minCount, Swift.min(rowFactory.maxCount, wantedRowCount)))
	}

	public var cellCount: Int {
		rowFactory.maxCount > 0 ? min(cells.count, rowCount * columnCount) : 0
	}

	public var isEmpty: Bool {
		columnCount == 0 || cellCount == 0
	}

	private var wrappedBandCount: Int {
		max(1, wrappedBandSizes.count)
	}

	public var size: CGSize {
		switch wrapping {
		case .vertical:
			.init(width: columns.size * CGFloat(wrappedBandCount), height: rows.size)
		case .horizontal:
			.init(
				width: columns.size,
				height: wrappedCrossMetrics.isEmpty
					? rows.size
					: zip(wrappedCrossOffsets, wrappedCrossMetrics).map { $0 + $1.size }.max() ?? 0
			)
		case .none:
			.init(width: columns.size, height: rows.size)
		}
	}

	public func resolving(
		bounds: CGSize,
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize],
		wrappedBands: [Int] = [],
		wrappedBandSizes: [CGFloat] = [],
		wrappedCrossMetrics: [TrackMetrics] = [],
		wrappedCrossOffsets: [CGFloat] = []
	) -> Self {
		.init(
			columnFactory: columnFactory,
			rowFactory: rowFactory,
			cells: cells,
			arrangement: arrangement,
			wrapping: wrapping,
			columns: columns,
			rows: rows,
			measured: measured,
			bounds: bounds,
			wrappedBands: wrappedBands,
			wrappedBandSizes: wrappedBandSizes,
			wrappedCrossMetrics: wrappedCrossMetrics,
			wrappedCrossOffsets: wrappedCrossOffsets
		)
	}

	public func cellIdx(_ c: Int, _ r: Int) -> Int {
		c + (r * columnCount)
	}

	public func cell(at index: Int) -> Cell? {
		guard index >= 0, index < cellCount else { return nil }
		return cells.indices.contains(index) ? cells[index] : nil
	}

	public func measuredSize(at index: Int) -> CGSize? {
		guard index >= 0, index < cellCount else { return nil }
		return measured.indices.contains(index) ? measured[index] : nil
	}

	public func forEachCell(inColumn column: Int, _ body: (_ index: Int) -> Void) {
		guard column >= 0, column < columnCount else { return }
		for row in 0..<rowCount {
			let index = cellIdx(column, row)
			guard index < cellCount else { continue }
			body(index)
		}
	}

	public func forEachCell(inRow row: Int, _ body: (_ index: Int) -> Void) {
		guard row >= 0, row < rowCount else { return }
		for column in 0..<columnCount {
			let index = cellIdx(column, row)
			guard index < cellCount else { continue }
			body(index)
		}
	}

	private func band(forWrappedTrack index: Int) -> Int {
		wrappedBands.indices.contains(index) ? wrappedBands[index] : 0
	}

	private func bandSize(_ band: Int) -> CGFloat {
		wrappedBandSizes.indices.contains(band) ? wrappedBandSizes[band] : 0
	}

	private func crossMetrics(for band: Int) -> TrackMetrics {
		wrappedCrossMetrics.indices.contains(band) ? wrappedCrossMetrics[band] : rows
	}

	private func crossOffset(for band: Int) -> CGFloat {
		wrappedCrossOffsets.indices.contains(band) ? wrappedCrossOffsets[band] : 0
	}

	public func allocatedRect(_ origin: CGPoint = .zero, column: Int) -> CGRect {
		switch wrapping {
		case .horizontal:
			let band = band(forWrappedTrack: column)
			let cross = crossMetrics(for: band)
			return .init(
				x: origin.x + columns.offsets[column],
				y: origin.y + crossOffset(for: band),
				width: columns.lengths[column],
				height: cross.size
			)
		case .vertical:
			return allocatedRects(origin, column: column).first ?? .zero
		case .none:
			return .init(
				x: origin.x + columns.offsets[column],
				y: origin.y,
				width: columns.lengths[column],
				height: rows.size
			)
		}
	}

	public func allocatedRect(_ origin: CGPoint = .zero, row: Int) -> CGRect {
		switch wrapping {
		case .vertical:
			let band = band(forWrappedTrack: row)
			return .init(
				x: origin.x + CGFloat(band) * columns.size,
				y: origin.y + rows.offsets[row],
				width: columns.size,
				height: rows.lengths[row]
			)
		case .horizontal:
			return allocatedRects(origin, row: row).first ?? .zero
		case .none:
			return .init(
				x: origin.x,
				y: origin.y + rows.offsets[row],
				width: columns.size,
				height: rows.lengths[row]
			)
		}
	}

	public func allocatedRect(_ origin: CGPoint = .zero, column: Int, row: Int) -> CGRect {
		var x = origin.x + columns.offsets[column]
		var y = origin.y + rows.offsets[row]
		switch wrapping {
		case .vertical:
			x += CGFloat(band(forWrappedTrack: row)) * columns.size
		case .horizontal:
			let band = band(forWrappedTrack: column)
			let cross = crossMetrics(for: band)
			y = origin.y + crossOffset(for: band) + cross.offsets[row]
		case .none:
			break
		}
		let height: CGFloat
		if wrapping == .horizontal {
			let band = band(forWrappedTrack: column)
			height = crossMetrics(for: band).lengths[row]
		} else {
			height = rows.lengths[row]
		}
		return .init(
			x: x,
			y: y,
			width: columns.lengths[column],
			height: height
		)
	}

	private func allocatedRects(_ origin: CGPoint, column: Int) -> [CGRect] {
		guard wrapping == .vertical else {
			return [allocatedRect(origin, column: column)]
		}
		return wrappedBandSizes.indices.map { band in
			.init(
				x: origin.x + CGFloat(band) * columns.size + columns.offsets[column],
				y: origin.y,
				width: columns.lengths[column],
				height: bandSize(band)
			)
		}
	}

	private func allocatedRects(_ origin: CGPoint, row: Int) -> [CGRect] {
		guard wrapping == .horizontal else {
			return [allocatedRect(origin, row: row)]
		}
		return wrappedBandSizes.indices.map { band in
			let cross = crossMetrics(for: band)
			return .init(
				x: origin.x,
				y: origin.y + crossOffset(for: band) + cross.offsets[row],
				width: bandSize(band),
				height: cross.lengths[row]
			)
		}
	}

	private var hasResolvedWrapping: Bool {
		wrapping != .none && wrappedBandSizes.count > 1
	}

	public func iterate(
		allocated: CGRect = CGRect(origin: .zero, size: .unbounded),
		truncate: Bool = false,
		column rColumn: ((ColumnIteration) -> Void)? = nil,
		row rRow: ((RowIteration) -> Void)? = nil,
		cell rCell: @escaping (CellIteration) -> Void
	) {
		guard hasResolvedWrapping else {
			iterateUnwrapped(
				allocated: allocated,
				truncate: truncate,
				column: rColumn,
				row: rRow,
				cell: rCell
			)
			return
		}

		let origin = allocated.origin
		if let rColumn {
			for c in 0..<columnCount {
				for rect in allocatedRects(origin, column: c) {
					if (truncate ? rect.maxX : rect.minX) > allocated.maxX { continue }
					if (truncate ? rect.maxY : rect.minY) > allocated.maxY { continue }
					if rect.size.isEmpty { continue }
					rColumn(.init(
						definition: self,
						track: columns.tracks[c],
						index: c,
						rect: rect
					))
				}
			}
		}

		for r in 0..<rowCount {
			let row = rows.tracks[r]
			let rowAlignment = row.align
			if let rRow {
				for rowRect in allocatedRects(origin, row: r) {
					if (truncate ? rowRect.maxX : rowRect.minX) > allocated.maxX { continue }
					if (truncate ? rowRect.maxY : rowRect.minY) > allocated.maxY { continue }
					if rowRect.size.isEmpty { continue }
					rRow(.init(
						definition: self,
						track: row,
						index: r,
						rect: rowRect
					))
				}
			}
			for c in 0..<columnCount {
				let rect = allocatedRect(origin, column: c, row: r)
				if (truncate ? rect.maxX : rect.minX) > allocated.maxX { continue }
				if (truncate ? rect.maxY : rect.minY) > allocated.maxY { continue }
				if rect.size.isEmpty { continue }
				let i = cellIdx(c, r)
				let columnAlignment = columns.tracks[c].align
				rCell(.init(
					definition: self,
					cell: cell(at: i),
					c: c,
					r: r,
					i: i,
					rect: rect,
					content: measuredSize(at: i),
					alignment: rowAlignment.union(columnAlignment)
				))
			}
		}
	}

	private func iterateUnwrapped(
		allocated: CGRect,
		truncate: Bool,
		column rColumn: ((ColumnIteration) -> Void)?,
		row rRow: ((RowIteration) -> Void)?,
		cell rCell: @escaping (CellIteration) -> Void
	) {
		let origin = allocated.origin
		let maxX = allocated.maxX
		let maxY = allocated.maxY

		if let rColumn {
			for c in 0..<columnCount {
				let rect = allocatedRect(origin, column: c)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				rColumn(.init(
					definition: self,
					track: columns.tracks[c],
					index: c,
					rect: rect
				))
			}
		}
		for r in 0..<rowCount {
			let rowRect = allocatedRect(origin, row: r)
			if (truncate ? rowRect.maxY : rowRect.minY) > maxY { break }
			if rowRect.size.isEmpty { continue }
			let row = rows.tracks[r]
			let rowAlignment = row.align
			if let rRow {
				rRow(.init(
					definition: self,
					track: row,
					index: r,
					rect: rowRect
				))
			}
			for c in 0..<columnCount {
				let rect = allocatedRect(origin, column: c, row: r)
				if (truncate ? rect.maxX : rect.minX) > maxX { break }
				if rect.size.isEmpty { continue }
				let i = cellIdx(c, r)
				let columnAlignment = columns.tracks[c].align
				rCell(.init(
					definition: self,
					cell: cell(at: i),
					c: c,
					r: r,
					i: i,
					rect: rect,
					content: measuredSize(at: i),
					alignment: rowAlignment.union(columnAlignment)
				))
			}
		}
	}

}
