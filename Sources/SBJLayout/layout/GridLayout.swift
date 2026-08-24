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

	private struct Measurement {
		let bounds: CGSize
		let size: CGSize
	}
	private var measurements: [Measurement?]
	private var measurementRevision: UInt = 0

	public init(
		columns: TrackFactory,
		rows: TrackFactory = .init(),
		cells: [Element],
		arrangement: TrackArrangement = .gaps,
		wrapping: GridWrapping = .none
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
		self.measurements = Array(repeating: nil, count: definition.cells.count)
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
				intrinsic: intrinsicColumnWidth
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .vertical, .none:
			columns.apply(
				available: bounds.width,
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
				intrinsic: intrinsicRowHeight
			)
			wrappedBands = wrapped.bands
			wrappedBandSizes = wrapped.bandSizes
		case .horizontal, .none:
			rows.apply(
				available: bounds.height,
				intrinsic: intrinsicRowHeight
			)
		}

		if definition.wrapping == .horizontal, !wrappedBandSizes.isEmpty {
			var offset: CGFloat = 0
			for band in wrappedBandSizes.indices {
				let bandRows = definition.rowLayout
				bandRows.apply(
					available: bounds.height,
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

	private func setMeasurement(at index: Int, _ measurement: Measurement) {
		guard measurements.indices.contains(index) else { return }
		let previous = measurements[index]
		if previous?.bounds != measurement.bounds || previous?.size != measurement.size {
			measurementRevision &+= 1
		}
		measurements[index] = measurement
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

