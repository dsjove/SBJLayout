import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("GridLayout")
struct GridLayoutTests {
	private final class MeasuringElement: TrackElement {
		private(set) var measuredBounds: [CGSize] = []
		let measureBlock: (CGSize) -> CGSize

		init(size: CGSize) {
			self.measureBlock = { _ in size }
		}

		init(measure: @escaping (CGSize) -> CGSize) {
			self.measureBlock = measure
		}

		func measure(bounds: CGSize) -> CGSize {
			measuredBounds.append(bounds)
			return measureBlock(bounds)
		}

		var measureCount: Int {
			measuredBounds.count
		}
	}

	@Test("An unconstrained intrinsic cell is measured only once")
	func intrinsicCellIsMeasuredOnce() {
		let cell = MeasuringElement(
			size: CGSize(width: 40, height: 12)
		)
		let layout = GridLayout(
			columns: .init([Track(.intrinsic())]),
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [40])
		#expect(definition.rows.lengths == [12])
		#expect(definition.measured == [CGSize(width: 40, height: 12)])
		#expect(cell.measureCount == 1)
		#expect(cell.measuredBounds == [.unbounded])
	}

	@Test("A fixed-width cell measurement is reused")
	func fixedCellMeasurementIsCached() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: 14)
		}
		let layout = GridLayout(
			columns: .init([Track(.fixed(80))]),
			cells: [cell],
			arrangement: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 200, height: .unbounded)
		)
		let second = layout.measure(
			bounds: CGSize(width: 200, height: .unbounded)
		)

		#expect(first.measured == [CGSize(width: 80, height: 14)])
		#expect(second.measured == first.measured)
		#expect(cell.measureCount == 1)
		#expect(
			cell.measuredBounds == [
				CGSize(width: 80, height: .unbounded)
			]
		)
	}

	@Test("A conditional fill column collapses when its content is empty")
	func conditionalFillCollapsesForEmptyContent() {
		let empty = MeasuringElement(size: .zero)
		let content = MeasuringElement(size: CGSize(width: 80, height: 20))
		let layout = GridLayout(
			columns: .init([
				Track(.fill(ifContent: true), gap: 12),
				Track(.intrinsic())
			]),
			cells: [empty, content],
			arrangement: .gaps
		)

		let definition = layout.measure(
			bounds: CGSize(width: 300, height: .unbounded)
		)

		#expect(definition.columns.lengths == [0, 80])
		#expect(definition.columns.offsets == [0, 0])
		#expect(definition.size.width == 80)
	}

	@Test("A conditional fill column fills when its content is nonempty")
	func conditionalFillUsesAvailableSpaceForContent() {
		let image = MeasuringElement(size: CGSize(width: 40, height: 50))
		let content = MeasuringElement(size: CGSize(width: 80, height: 20))
		let layout = GridLayout(
			columns: .init([
				Track(.fill(ifContent: true)),
				Track(.intrinsic())
			]),
			cells: [image, content],
			arrangement: .tight
		)

		let definition = layout.measure(
			bounds: CGSize(width: 300, height: .unbounded)
		)

		#expect(definition.columns.lengths == [220, 80])
		#expect(definition.columns.offsets == [0, 220])
		#expect(definition.size.width == 300)
	}

	@Test("A fill cell is remeasured only when its resolved width changes")
	func fillCellRemeasuresForChangedWidth() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 10)
		}
		let layout = GridLayout(
			columns: .init([Track(.fill())]),
			cells: [cell],
			arrangement: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let repeated = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let changed = layout.measure(
			bounds: CGSize(width: 150, height: .unbounded)
		)

		#expect(first.measured == [CGSize(width: 100, height: 10)])
		#expect(repeated.measured == first.measured)
		#expect(changed.measured == [CGSize(width: 150, height: 15)])
		#expect(cell.measureCount == 2)
		#expect(
			cell.measuredBounds == [
				CGSize(width: 100, height: .unbounded),
				CGSize(width: 150, height: .unbounded)
			]
		)
	}

	@Test("Row calculation reuses cached cell measurements")
	func rowCalculationUsesCachedMeasurements() {
		let first = MeasuringElement(
			size: CGSize(width: 20, height: 8)
		)
		let second = MeasuringElement(
			size: CGSize(width: 30, height: 15)
		)
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(40)),
				Track(.fixed(40))
			]),
			cells: [first, second],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [15])
		#expect(first.measureCount == 1)
		#expect(second.measureCount == 1)
	}

	@Test("Changed cell measurements invalidate resolved row heights")
	func changedMeasurementsInvalidateRows() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 5)
		}
		let layout = GridLayout(
			columns: .init([Track(.fill())]),
			rows: .init(row: Track(.intrinsic())),
			cells: [cell],
			arrangement: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 50, height: .unbounded)
		)
		let second = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)

		#expect(first.rows.lengths == [10])
		#expect(second.rows.lengths == [20])
		#expect(cell.measureCount == 2)
	}

	@Test("Zero-width resolved columns cache zero without measuring the cell")
	func zeroWidthColumnDoesNotMeasureCell() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 10)
		)
		let layout = GridLayout(
			columns: .init([Track(.fixed(0))]),
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.measured == [.zero])
		#expect(definition.rows.lengths == [0])
		#expect(cell.measureCount == 0)
	}

	@Test("Measure publishes the latest definition while preserving earlier snapshots")
	func measurePublishesLatestImmutableDefinition() {
		let cell = MeasuringElement { bounds in
			CGSize(width: bounds.width, height: bounds.width / 10)
		}
		let layout = GridLayout(
			columns: .init([Track(.fill())]),
			cells: [cell],
			arrangement: .tight
		)

		let first = layout.measure(
			bounds: CGSize(width: 100, height: .unbounded)
		)
		let second = layout.measure(
			bounds: CGSize(width: 150, height: .unbounded)
		)

		#expect(first.bounds == CGSize(width: 100, height: .unbounded))
		#expect(first.size == CGSize(width: 100, height: 10))
		#expect(first.measured == [CGSize(width: 100, height: 10)])

		#expect(second.bounds == CGSize(width: 150, height: .unbounded))
		#expect(second.size == CGSize(width: 150, height: 15))
		#expect(second.measured == [CGSize(width: 150, height: 15)])

		#expect(layout.definition.bounds == second.bounds)
		#expect(layout.definition.size == second.size)
		#expect(layout.definition.measured == second.measured)
	}


	@Test("Maximum rows prevent excluded cells from being measured")
	func maximumRowsExcludeMeasurements() {
		let cells = (0..<5).map { _ in
			MeasuringElement(size: CGSize(width: 10, height: 10))
		}
		let layout = GridLayout(
			columns: .init([
				Track(.fixed(20)),
				Track(.fixed(20))
			]),
			rows: .init(row: Track(.intrinsic()), minCount: 0, maxCount: 2),
			cells: cells,
			arrangement: .tight
		)

		_ = layout.measure(bounds: .unbounded)

		#expect(cells[0].measureCount == 1)
		#expect(cells[1].measureCount == 1)
		#expect(cells[2].measureCount == 1)
		#expect(cells[3].measureCount == 1)
		#expect(cells[4].measureCount == 0)
	}

	@Test("Empty columns do not measure cells")
	func emptyColumnsDoNotMeasureCells() {
		let cell = MeasuringElement(
			size: CGSize(width: 10, height: 10)
		)
		let layout = GridLayout(
			columns: .init([]),
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.size == .zero)
		#expect(definition.measured == [.zero])
		#expect(cell.measureCount == 0)
	}

	@Test("An intrinsic column uses its widest visible cell")
	func intrinsicColumnUsesWidestCell() {
		let cells = [
			MeasuringElement(size: CGSize(width: 20, height: 5)),
			MeasuringElement(size: CGSize(width: 45, height: 6)),
			MeasuringElement(size: CGSize(width: 30, height: 7))
		]
		let layout = GridLayout(
			columns: .init([Track(.intrinsic())]),
			cells: cells,
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [45])
		#expect(cells.map(\.measureCount) == [2, 1, 2])

		#expect(cells[0].measuredBounds == [
			.unbounded,
			CGSize(width: 45, height: .unbounded)
		])
		#expect(cells[1].measuredBounds == [
			.unbounded
		])
		#expect(cells[2].measuredBounds == [
			.unbounded,
			CGSize(width: 45, height: .unbounded)
		])
	}

}

extension GridLayoutTests {
	@Test("Column factory aggregate reducer combines intrinsic widths")
	func columnFactoryAggregateReducer() {
		let cells = [
			MeasuringElement(size: CGSize(width: 10, height: 4)),
			MeasuringElement(size: CGSize(width: 15, height: 6))
		]
		let layout = GridLayout(
			columns: TrackFactory(.intrinsic(), aggregate: { $0.reduce(0, +) }, minCount: 1, maxCount: 1),
			cells: cells,
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [25])
	}

	@Test("Row factory aggregate reducer combines measured heights")
	func rowFactoryAggregateReducer() {
		let cells = [
			MeasuringElement(size: CGSize(width: 10, height: 4)),
			MeasuringElement(size: CGSize(width: 10, height: 6))
		]
		let layout = GridLayout(
			columns: TrackFactory([
				Track(.fixed(10)),
				Track(.fixed(10))
			]),
			rows: TrackFactory(.intrinsic(), aggregate: { $0.reduce(0, +) }),
			cells: cells,
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [10])
	}

	@Test("Track factory mapping controls generated column order")
	func trackFactoryMappingControlsColumns() {
		let tracks = [Track(.fixed(10)), Track(.fixed(20)), Track(.fixed(30))]
		let layout = GridLayout(
			columns: TrackFactory(tracks, map: { tracks.count - 1 - $0 }),
			cells: (0..<3).map { _ in MeasuringElement(size: .zero) },
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [30, 20, 10])
	}

	@Test("Minimum rows use the client-resolved placeholder sentinel")
	func minimumRowsUseClientResolvedPlaceholderSentinel() {
		let cell = MeasuringElement(size: CGSize(width: 10, height: 12))
		var requestedRowIndices: [Int] = []
		let placeholderHeight: CGFloat = 44
		let rows = TrackFactory(minCount: 3) { index in
			requestedRowIndices.append(index)
			return index == TrackFactory.placeholderIndex
				? Track(.intrinsic(min: placeholderHeight))
				: Track(.intrinsic())
		}
		let layout = GridLayout(
			columns: .init([Track(.fixed(10))]),
			rows: rows,
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.wantedRowCount == 1)
		#expect(definition.rowCount == 3)
		#expect(requestedRowIndices == [0, TrackFactory.placeholderIndex, TrackFactory.placeholderIndex])
		#expect(definition.rows.lengths == [12, placeholderHeight, placeholderHeight])
		#expect(definition.rows.size == 100)
	}

	@Test("Concrete rows never receive the placeholder sentinel")
	func concreteRowsNeverReceivePlaceholderSentinel() {
		let cells = (0..<3).map { _ in
			MeasuringElement(size: CGSize(width: 10, height: 8))
		}
		var requestedRowIndices: [Int] = []
		let rows = TrackFactory(minCount: 2, maxCount: 3) { index in
			requestedRowIndices.append(index)
			return Track(.intrinsic())
		}
		let layout = GridLayout(
			columns: .init([Track(.fixed(10))]),
			rows: rows,
			cells: cells,
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.wantedRowCount == 3)
		#expect(definition.rowCount == 3)
		#expect(requestedRowIndices == [0, 1, 2])
		#expect(definition.rows.lengths == [8, 8, 8])
	}


	@Test("Column aggregate receives every intrinsic width including zero")
	func columnAggregateReceivesZeros() {
		let cells = [
			MeasuringElement(size: CGSize(width: 20, height: 4)),
			MeasuringElement(size: CGSize(width: 0, height: 5)),
			MeasuringElement(size: CGSize(width: 10, height: 6))
		]
		var received: [CGFloat] = []
		let layout = GridLayout(
			columns: TrackFactory(
				.intrinsic(),
				aggregate: {
					received = $0
					return $0.max()
				},
				minCount: 1,
				maxCount: 1
			),
			cells: cells,
			arrangement: .tight
		)

		_ = layout.measure(bounds: .unbounded)

		#expect(received == [20, 0, 10])
	}

	@Test("Nil column aggregate resolves to zero intrinsic width")
	func nilColumnAggregateMeansZero() {
		let cell = MeasuringElement(size: CGSize(width: 20, height: 8))
		let layout = GridLayout(
			columns: TrackFactory(
				col: Track(
					.intrinsic(),
					aggregate: { _ in nil }
				)
			),
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.columns.lengths == [0])
	}

	@Test("Nil row aggregate resolves to zero intrinsic height")
	func nilRowAggregateMeansZero() {
		let cell = MeasuringElement(size: CGSize(width: 10, height: 8))
		let layout = GridLayout(
			columns: TrackFactory([Track(.fixed(10))]),
			rows: TrackFactory(.intrinsic(), aggregate: { _ in nil }),
			cells: [cell],
			arrangement: .tight
		)

		let definition = layout.measure(bounds: .unbounded)

		#expect(definition.rows.lengths == [0])
	}

}
