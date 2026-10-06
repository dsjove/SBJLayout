import CoreGraphics

public final class GridLayout<Element: TrackElement> {
	public typealias Cell = Element
	public typealias Definition = GridDefinition<Cell>
	public typealias TrackIteration = Definition.TrackIteration
	public typealias ColumnIteration = Definition.ColumnIteration
	public typealias RowIteration = Definition.RowIteration
	public typealias CellIteration = Definition.CellIteration

	public private(set) var definition: Definition
	private let columns: TrackLayout
	private let rows: TrackLayout

	// Minimum-content layout has independent track state so a minimum probe cannot
	// disturb the resolved normal layout used later for rendering. Both modes still
	// share this GridLayout's cells and measurement bookkeeping.
	private let minimumColumns: TrackLayout
	private let minimumRows: TrackLayout

	private struct Measurement {
		let bounds: CGSize
		let size: CGSize
	}
	private var measurements: [Measurement?]
	private var minimumMeasurements: [Measurement?]
	private var minimumMeasurementHistory: [[Measurement]]
	private let minimumMeasurementHistoryLimit = 4
	private var measurementRevision: UInt = 0
	private var minimumMeasurementRevision: UInt = 0

	public init(
		columns: TrackFactory,
		rows: TrackFactory = .init(),
		cells: [Element],
		arrangement: TrackArrangement = .gaps,
		wrapping: TrackAxis? = nil
	) {
		let definition = Definition(
			columns: columns,
			rows: rows,
			cells: cells,
			arrangement: arrangement,
			wrapping: wrapping
		)
		self.definition = definition
		self.columns = definition.columnLayout
		self.rows = definition.rowLayout
		self.minimumColumns = definition.columnLayout
		self.minimumRows = definition.rowLayout
		self.measurements = Array(repeating: nil, count: definition.cells.count)
		self.minimumMeasurements = Array(repeating: nil, count: definition.cells.count)
		self.minimumMeasurementHistory = Array(repeating: [], count: definition.cells.count)
	}

	public func measure(bounds: CGSize) -> Definition {
		var wrappedBands: [Int] = []
		var wrappedBandSizes: [CGFloat] = []
		var wrappedCrossMetrics: [TrackMetrics] = []
		var wrappedCrossOffsets: [CGFloat] = []

		switch definition.wrapping {
		case .horizontal:
			let wrapped = columns.applyWrapped(
				available: bounds.width,
				minimumIntrinsic: minimumColumnWidth,
				intrinsic: intrinsicColumnWidth
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .vertical, .none:
			columns.apply(
				available: bounds.width,
				minimumIntrinsic: minimumColumnWidth,
				intrinsic: intrinsicColumnWidth
			)
		}

		let revisionBeforeResolvedMeasurement = measurementRevision
		measureElementsForResolvedColumns()
		if measurementRevision != revisionBeforeResolvedMeasurement {
			rows.invalidate()
		}

		switch definition.wrapping {
		case .vertical:
			let wrapped = rows.applyWrapped(
				available: bounds.height,
				minimumIntrinsic: minimumRowHeight,
				intrinsic: intrinsicRowHeight
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .horizontal, .none:
			rows.apply(
				available: bounds.height,
				minimumIntrinsic: minimumRowHeight,
				intrinsic: intrinsicRowHeight
			)
		}

		if definition.wrapping == .horizontal, !wrappedBandSizes.isEmpty {
			var offset: CGFloat = 0
			for band in wrappedBandSizes.indices {
				let bandRows = definition.rowLayout
				bandRows.apply(
					available: bounds.height,
					minimumIntrinsic: { [self] row, track, bound in
						minimumRowHeight(row, track: track, bound, horizontalBand: band, wrappedBands: wrappedBands)
					},
					intrinsic: { [self] row, track, bound in
						intrinsicRowHeight(row, track: track, bound, horizontalBand: band, wrappedBands: wrappedBands)
					}
				)
				wrappedCrossOffsets.append(offset)
				wrappedCrossMetrics.append(bandRows.metrics)
				offset += bandRows.size + trailingGap(in: bandRows.metrics)
			}
		}

		definition = definition.resolving(
			bounds: bounds,
			columns: columns.metrics,
			rows: rows.metrics,
			measured: measurements.map { $0?.size ?? .zero },
			wrappedBands: wrappedBands,
			wrappedBandSizes: wrappedBandSizes,
			wrappedCrossMetrics: wrappedCrossMetrics,
			wrappedCrossOffsets: wrappedCrossOffsets
		)
		return definition
	}

	func minimumMeasure(bounds: CGSize) -> CGSize {
		var wrappedBands: [Int] = []
		var wrappedBandSizes: [CGFloat] = []
		var wrappedCrossMetrics: [TrackMetrics] = []
		var wrappedCrossOffsets: [CGFloat] = []

		switch definition.wrapping {
		case .horizontal:
			let wrapped = minimumColumns.applyWrapped(
				available: bounds.width,
				minimumIntrinsic: minimumContentColumnWidth,
				intrinsic: minimumContentColumnWidth
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .vertical, .none:
			minimumColumns.apply(
				available: bounds.width,
				minimumIntrinsic: minimumContentColumnWidth,
				intrinsic: minimumContentColumnWidth
			)
		}

		let revisionBeforeResolvedMeasurement = minimumMeasurementRevision
		minimumMeasureElementsForResolvedColumns()
		if minimumMeasurementRevision != revisionBeforeResolvedMeasurement {
			minimumRows.invalidate()
		}

		switch definition.wrapping {
		case .vertical:
			let wrapped = minimumRows.applyWrapped(
				available: bounds.height,
				minimumIntrinsic: minimumContentRowHeight,
				intrinsic: intrinsicMinimumContentRowHeight
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .horizontal, .none:
			minimumRows.apply(
				available: bounds.height,
				minimumIntrinsic: minimumContentRowHeight,
				intrinsic: intrinsicMinimumContentRowHeight
			)
		}

		if definition.wrapping == .horizontal, !wrappedBandSizes.isEmpty {
			var offset: CGFloat = 0
			for band in wrappedBandSizes.indices {
				let bandRows = definition.rowLayout
				bandRows.apply(
					available: bounds.height,
					minimumIntrinsic: { [self] row, track, bound in
						minimumContentRowHeight(row, track: track, bound, horizontalBand: band, wrappedBands: wrappedBands)
					},
					intrinsic: { [self] row, track, bound in
						intrinsicMinimumContentRowHeight(row, track: track, bound, horizontalBand: band, wrappedBands: wrappedBands)
					}
				)
				wrappedCrossOffsets.append(offset)
				wrappedCrossMetrics.append(bandRows.metrics)
				offset += bandRows.size + trailingGap(in: bandRows.metrics)
			}
		}

		return definition.resolving(
			bounds: bounds,
			columns: minimumColumns.metrics,
			rows: minimumRows.metrics,
			measured: minimumMeasurements.map { $0?.size ?? .zero },
			wrappedBands: wrappedBands,
			wrappedBandSizes: wrappedBandSizes,
			wrappedCrossMetrics: wrappedCrossMetrics,
			wrappedCrossOffsets: wrappedCrossOffsets
		).size
	}

	func resolvedDefinition(for measured: CGSize) -> Definition {
		if definition.bounds != nil && definition.size == measured {
			return definition
		}
		return measure(bounds: measured)
	}

	private func intrinsicColumnWidth(_ column: Int, _ track: Track, _ bound: CGFloat) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.rowCount)
		definition.forEachCell(inColumn: column) { index in
			candidates.append(
				measureElement(
					at: index,
					bounds: CGSize(width: bound, height: .unbounded)
				).width
			)
		}
		return track.aggregate(candidates) ?? 0
	}

	private func minimumColumnWidth(_ column: Int, _ track: Track, _ bound: CGFloat) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.rowCount)
		definition.forEachCell(inColumn: column) { index in
			candidates.append(
				minimumMeasureElement(
					at: index,
					bounds: CGSize(width: bound, height: .unbounded)
				).width
			)
		}
		return track.aggregate(candidates) ?? 0
	}

	private func minimumContentColumnWidth(_ column: Int, _ track: Track, _ bound: CGFloat) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.rowCount)
		definition.forEachCell(inColumn: column) { index in
			candidates.append(
				minimumMeasureElement(
					at: index,
					bounds: CGSize(width: bound, height: .unbounded)
				).width
			)
		}
		return track.aggregate(candidates) ?? 0
	}

	private func measureElementsForResolvedColumns() {
		for column in 0..<definition.columnCount {
			guard columns.lengths.indices.contains(column) else { continue }
			let width = columns.lengths[column]
			let resolvedBounds = CGSize(width: width, height: .unbounded)

			definition.forEachCell(inColumn: column) { index in
				guard width > 0 else {
					setMeasurement(at: index, Measurement(bounds: resolvedBounds, size: .zero))
					return
				}
				if canReuseIntrinsicMeasurement(at: index, resolvedWidth: width) {
					return
				}
				measureElement(at: index, bounds: resolvedBounds)
			}
		}
	}

	private func minimumMeasureElementsForResolvedColumns() {
		for column in 0..<definition.columnCount {
			guard minimumColumns.lengths.indices.contains(column) else { continue }
			let width = minimumColumns.lengths[column]
			let resolvedBounds = CGSize(width: width, height: .unbounded)

			definition.forEachCell(inColumn: column) { index in
				guard width > 0 else {
					setMinimumMeasurement(at: index, Measurement(bounds: resolvedBounds, size: .zero))
					return
				}
				if canReuseMinimumIntrinsicMeasurement(at: index, resolvedWidth: width) {
					return
				}
				_ = minimumMeasureElement(at: index, bounds: resolvedBounds)
			}
		}
	}

	private func intrinsicRowHeight(_ row: Int, track: Track, _ bound: CGFloat) -> CGFloat {
		intrinsicRowHeight(row, track: track, bound, horizontalBand: nil, wrappedBands: [])
	}

	private func intrinsicRowHeight(
		_ row: Int,
		track: Track,
		_ bound: CGFloat,
		horizontalBand: Int?,
		wrappedBands: [Int]
	) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.columnCount)
		for column in 0..<definition.columnCount {
			if let horizontalBand {
				guard wrappedBands.indices.contains(column), wrappedBands[column] == horizontalBand else { continue }
			}
			let index = definition.cellIdx(column, row)
			guard index < definition.cellCount else { continue }
			if let candidate = measurements[index]?.size.height {
				candidates.append(candidate)
			}
		}
		return track.aggregate(candidates) ?? 0
	}

	private func minimumRowHeight(_ row: Int, track: Track, _ bound: CGFloat) -> CGFloat {
		minimumRowHeight(row, track: track, bound, horizontalBand: nil, wrappedBands: [])
	}

	private func minimumRowHeight(
		_ row: Int,
		track: Track,
		_ bound: CGFloat,
		horizontalBand: Int?,
		wrappedBands: [Int]
	) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.columnCount)
		for column in 0..<definition.columnCount {
			if let horizontalBand {
				guard wrappedBands.indices.contains(column), wrappedBands[column] == horizontalBand else { continue }
			}
			let index = definition.cellIdx(column, row)
			guard index < definition.cellCount else { continue }
			let width = columns.lengths.indices.contains(column) ? columns.lengths[column] : .unbounded
			let size = minimumMeasureElement(
				at: index,
				bounds: CGSize(width: width, height: bound)
			)
			candidates.append(size.height)
		}
		return track.aggregate(candidates) ?? 0
	}

	private func intrinsicMinimumContentRowHeight(_ row: Int, track: Track, _ bound: CGFloat) -> CGFloat {
		intrinsicMinimumContentRowHeight(row, track: track, bound, horizontalBand: nil, wrappedBands: [])
	}

	private func intrinsicMinimumContentRowHeight(
		_ row: Int,
		track: Track,
		_ bound: CGFloat,
		horizontalBand: Int?,
		wrappedBands: [Int]
	) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.columnCount)
		for column in 0..<definition.columnCount {
			if let horizontalBand {
				guard wrappedBands.indices.contains(column), wrappedBands[column] == horizontalBand else { continue }
			}
			let index = definition.cellIdx(column, row)
			guard index < definition.cellCount else { continue }
			if let candidate = minimumMeasurements[index]?.size.height {
				candidates.append(candidate)
			}
		}
		return track.aggregate(candidates) ?? 0
	}

	private func minimumContentRowHeight(_ row: Int, track: Track, _ bound: CGFloat) -> CGFloat {
		minimumContentRowHeight(row, track: track, bound, horizontalBand: nil, wrappedBands: [])
	}

	private func minimumContentRowHeight(
		_ row: Int,
		track: Track,
		_ bound: CGFloat,
		horizontalBand: Int?,
		wrappedBands: [Int]
	) -> CGFloat {
		var candidates: [CGFloat] = []
		candidates.reserveCapacity(definition.columnCount)
		for column in 0..<definition.columnCount {
			if let horizontalBand {
				guard wrappedBands.indices.contains(column), wrappedBands[column] == horizontalBand else { continue }
			}
			let index = definition.cellIdx(column, row)
			guard index < definition.cellCount else { continue }
			let width = minimumColumns.lengths.indices.contains(column) ? minimumColumns.lengths[column] : .unbounded
			let size = minimumMeasureElement(
				at: index,
				bounds: CGSize(width: width, height: bound)
			)
			candidates.append(size.height)
		}
		return track.aggregate(candidates) ?? 0
	}

	private func trailingGap(in metrics: TrackMetrics) -> CGFloat {
		guard definition.arrangement == .gaps else { return 0 }
		for index in metrics.tracks.indices.reversed() where metrics.lengths[index] > 0 {
			return max(metrics.tracks[index].gap, 0)
		}
		return 0
	}

	private func canReuseIntrinsicMeasurement(at index: Int, resolvedWidth: CGFloat) -> Bool {
		guard let cached = measurements[index] else { return false }
		return cached.bounds.width == .unbounded
			&& cached.bounds.height == .unbounded
			&& cached.size.width == resolvedWidth
	}

	private func canReuseMinimumIntrinsicMeasurement(at index: Int, resolvedWidth: CGFloat) -> Bool {
		guard let cached = minimumMeasurements[index] else { return false }
		return cached.bounds.width == .unbounded
			&& cached.bounds.height == .unbounded
			&& cached.size.width == resolvedWidth
	}

	private func setMeasurement(at index: Int, _ measurement: Measurement) {
		guard measurements.indices.contains(index) else { return }
		let previous = measurements[index]
		if previous?.bounds != measurement.bounds || previous?.size != measurement.size {
			measurementRevision &+= 1
		}
		measurements[index] = measurement
	}

	private func setMinimumMeasurement(at index: Int, _ measurement: Measurement) {
		guard minimumMeasurements.indices.contains(index) else { return }
		let previous = minimumMeasurements[index]
		if previous?.bounds != measurement.bounds || previous?.size != measurement.size {
			minimumMeasurementRevision &+= 1
		}
		minimumMeasurements[index] = measurement

		guard minimumMeasurementHistory.indices.contains(index) else { return }
		var history = minimumMeasurementHistory[index]
		if let existing = history.firstIndex(where: { $0.bounds == measurement.bounds }) {
			history.remove(at: existing)
		}
		history.append(measurement)
		if history.count > minimumMeasurementHistoryLimit {
			history.removeFirst(history.count - minimumMeasurementHistoryLimit)
		}
		minimumMeasurementHistory[index] = history
	}

	private func minimumMeasureElement(at index: Int, bounds: CGSize) -> CGSize {
		guard definition.cells.indices.contains(index) else { return .zero }
		if let cached = minimumMeasurements[index], cached.bounds == bounds {
			return cached.size
		}
		if minimumMeasurementHistory.indices.contains(index),
		   let cached = minimumMeasurementHistory[index].last(where: { $0.bounds == bounds }) {
			setMinimumMeasurement(at: index, cached)
			return cached.size
		}
		let size = definition.cells[index].minimumMeasure(bounds: bounds)
		setMinimumMeasurement(
			at: index,
			Measurement(bounds: bounds, size: size)
		)
		return size
	}

	@discardableResult
	private func measureElement(at index: Int, bounds: CGSize) -> CGSize {
		guard definition.cells.indices.contains(index) else { return .zero }
		if let cached = measurements[index], cached.bounds == bounds {
			return cached.size
		}
		let size = definition.cells[index].measure(bounds: bounds)
		setMeasurement(
			at: index,
			Measurement(bounds: bounds, size: size)
		)
		return size
	}
}
