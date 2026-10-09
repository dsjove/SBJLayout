import CoreGraphics

public struct GridDefinition<Cell: TrackElement> {
    public struct RowAccessory {
        public let inputStride: Int
        public let slot: Int
        public let track: Track
        public let physicalSlots: [Int]
        public init(inputStride: Int, slot: Int, track: Track, physicalSlots: [Int]) {
            self.inputStride = inputStride
            self.slot = slot
            self.track = track
            self.physicalSlots = physicalSlots
        }
    }
    public let accessories: [RowAccessory]
    public func accessoryIndex(row: Int, accessory: RowAccessory) -> Int? {
        let index = row * accessory.inputStride + accessory.slot
        return index >= 0 && index < cellCount ? index : nil
    }
    private func accessoryContentHeight(row: Int, accessory: RowAccessory) -> CGFloat {
        guard let index = accessoryIndex(row: row, accessory: accessory),
              measured.indices.contains(index) else { return 0 }
        return max(0, measured[index].height)
    }
    private func accessoryAllocatedHeight(row: Int, accessory: RowAccessory) -> CGFloat {
        let height = accessoryContentHeight(row: row, accessory: accessory)
        return height > 0 ? height + max(0, accessory.track.gap) : 0
    }
    public func accessoryHeight(row: Int) -> CGFloat {
        accessories.reduce(0) { $0 + accessoryAllocatedHeight(row: row, accessory: $1) }
    }
    private func accessoryHeight(row: Int, placement: Track.AccessoryPlacement) -> CGFloat {
        accessories.filter { $0.track.role.accessoryPlacement == placement }
            .reduce(0) { $0 + accessoryAllocatedHeight(row: row, accessory: $1) }
    }
    public func accessoryRect(_ origin: CGPoint = .zero, row: Int, accessory: RowAccessory) -> CGRect? {
        let height = accessoryContentHeight(row: row, accessory: accessory)
        guard height > 0 else { return nil }
        let rowRect = allocatedRect(origin, row: row)
        let preceding = accessories.filter {
            $0.slot < accessory.slot && $0.track.role.accessoryPlacement == accessory.track.role.accessoryPlacement
        }.reduce(CGFloat.zero) { $0 + accessoryAllocatedHeight(row: row, accessory: $1) }
        let y: CGFloat
        switch accessory.track.role.accessoryPlacement {
        case .before:
            y = rowRect.minY + preceding
        case .after:
            y = rowRect.maxY - accessoryHeight(row: row, placement: .after) + preceding + max(0, accessory.track.gap)
        case .none:
            return nil
        }
        return CGRect(x: rowRect.minX, y: y, width: rowRect.width, height: height)
    }

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
	public let wrapping: TrackAxis?

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
		wrapping: TrackAxis? = nil,
        accessories: [RowAccessory] = []
	) {
		self.init(
			columnFactory: columns,
            accessories: accessories,
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
        accessories: [RowAccessory],
		rowFactory: TrackFactory,
		cells: [Cell],
		arrangement: TrackArrangement,
		wrapping: TrackAxis?,
		columns: TrackMetrics,
		rows: TrackMetrics,
		measured: [CGSize],
		bounds: CGSize?,
		wrappedBands: [Int],
		wrappedBandSizes: [CGFloat],
		wrappedCrossMetrics: [TrackMetrics],
		wrappedCrossOffsets: [CGFloat]
	) {
		self.accessories = accessories
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
		inputStride > 0 ? (cells.count + inputStride - 1) / inputStride : 0
	}

	public var rowCount: Int {
		max(0, max(rowFactory.minCount, Swift.min(rowFactory.maxCount, wantedRowCount)))
	}

	public var cellCount: Int {
		rowFactory.maxCount > 0 ? min(cells.count, rowCount * inputStride) : 0
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
            accessories: accessories,
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

	public var inputStride: Int { accessories.first?.inputStride ?? columnCount }

	public func cellIdx(_ c: Int, _ r: Int) -> Int {
		(accessories.first?.physicalSlots[c] ?? c) + (r * inputStride)
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
			height = max(0, rows.lengths[row] - accessoryHeight(row: row))
		}
		return .init(
			x: x,
			y: y + ((wrapping != .horizontal && accessoryHeight(row: row, placement: .before) > 0) ? accessoryHeight(row: row, placement: .before) : 0),
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

    // A table may retain zero-width columns (for example, when its header-only
    // columns are suppressed). Do not emit a trailing separator callback for
    // the last *visible* ordinary column in an accessory table.
    private func hasVisibleColumn(after column: Int) -> Bool {
        guard column + 1 < columnCount else { return false }
        return ((column + 1)..<columnCount).contains { index in
            columns.lengths.indices.contains(index) && columns.lengths[index] > 0
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
		if let rColumn, accessories.isEmpty {
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
            if let rColumn, !accessories.isEmpty {
                for c in 0..<columnCount {
                    let rect = allocatedRect(origin, column: c, row: r)
                    guard !rect.isEmpty, hasVisibleColumn(after: c) else { continue }
                    rColumn(.init(definition: self, track: columns.tracks[c], index: c, rect: rect))
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
            for accessory in accessories {
                guard let i = accessoryIndex(row: r, accessory: accessory),
                      let rect = accessoryRect(origin, row: r, accessory: accessory), !rect.isEmpty else { continue }
                rCell(.init(definition: self, cell: cell(at: i), c: columnCount, r: r, i: i,
                            rect: rect, content: measuredSize(at: i), alignment: accessory.track.align))
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

		if let rColumn, accessories.isEmpty {
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
            if let rColumn, !accessories.isEmpty {
                for c in 0..<columnCount {
                    let rect = allocatedRect(origin, column: c, row: r)
                    guard !rect.isEmpty, hasVisibleColumn(after: c) else { continue }
                    rColumn(.init(definition: self, track: columns.tracks[c], index: c, rect: rect))
                }
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
            for accessory in accessories {
                guard let i = accessoryIndex(row: r, accessory: accessory),
                      let rect = accessoryRect(origin, row: r, accessory: accessory), !rect.isEmpty else { continue }
                rCell(.init(definition: self, cell: cell(at: i), c: columnCount, r: r, i: i,
                            rect: rect, content: measuredSize(at: i), alignment: accessory.track.align))
            }
		}
	}

}
