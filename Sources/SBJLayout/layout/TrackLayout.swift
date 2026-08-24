import CoreGraphics

public struct TrackMetrics {
	public internal(set) var tracks: [Track]
	public internal(set) var lengths: [CGFloat]
	public internal(set) var offsets: [CGFloat]
	public internal(set) var size: CGFloat

	public init(
		tracks: [Track] = [],
		lengths: [CGFloat] = [],
		offsets: [CGFloat] = [],
		size: CGFloat = 0
	) {
		self.tracks = tracks
		self.lengths = lengths
		self.offsets = offsets
		self.size = size
	}
}

public class TrackLayout {
// Init
	public let factory: ((Int)->Track)?
	public let count: Int
	public var isEmpty: Bool { count == 0 }
	public let layout: TrackArrangement
// Resolved snapshot
	public private(set) var metrics: TrackMetrics
	public var tracks: [Track] { metrics.tracks }
	public var lengths: [CGFloat] { metrics.lengths }
	public var offsets: [CGFloat] { metrics.offsets }
	public var size: CGFloat { metrics.size }
// Prepared (lengths and sizes do not include fills
	public private(set) var fillCount: Int
	public var hasFill: Bool { fillCount > 0 }
	private var preparedLengths: [CGFloat]
	private var preparedSize: CGFloat
// Can change with hasFill
	private var lastBounds: CGFloat?

	public init(
		factory: ((Int)->Track)? = nil,
		tracks: [Track] = [],
		count :Int? = nil,
		layout: TrackArrangement
	) {
		self.factory = factory
		self.metrics = .init(tracks: tracks)
		self.count = count ?? tracks.count
		self.layout = layout
		self.fillCount = 0
		self.preparedLengths = []
		self.preparedSize = 0
	}

	public func invalidate() {
		fillCount = 0
		preparedLengths = []
		preparedSize = 0
		lastBounds = nil
		metrics.lengths = []
		metrics.offsets = []
		metrics.size = 0
	}


	internal func applyWrapped(
		available: CGFloat,
		intrinsic: (
			_ index: Int,
			_ element: Track,
			_ bound: CGFloat
		) -> CGFloat
	) -> WrappedTrackMetrics {
		if let factory, metrics.tracks.isEmpty {
			metrics.tracks = (0..<count).map(factory)
		}
		guard !metrics.tracks.isEmpty else {
			return .init(metrics: metrics, bands: [], bandSizes: [])
		}
		prepare(intrinsic)

		guard available != .unbounded, layout != .stack else {
			calculateFills(available)
			return .init(
				metrics: metrics,
				bands: Array(repeating: 0, count: metrics.tracks.count),
				bandSizes: metrics.tracks.isEmpty ? [] : [metrics.size]
			)
		}

		var lengths = preparedLengths
		var offsets = Array(repeating: CGFloat.zero, count: metrics.tracks.count)
		var bands = Array(repeating: 0, count: metrics.tracks.count)
		var bandSizes: [CGFloat] = []
		var band = 0
		var position: CGFloat = 0
		var previousVisibleIndex: Int?
		var bandHasVisibleTrack = false

		func finishBand() {
			bandSizes.append(position)
			band += 1
			position = 0
			previousVisibleIndex = nil
			bandHasVisibleTrack = false
		}

		for index in metrics.tracks.indices {
			let track = metrics.tracks[index]
			bands[index] = band

			switch track.length {
			case .fill(let fraction, _, let maximum):
				let lockedAtZero = maximum <= 0 || fraction.map { $0 <= 0 } ?? false
				guard !lockedAtZero else {
					lengths[index] = 0
				offsets[index] = position
					continue
				}

				let gap = (layout == .gaps && bandHasVisibleTrack && previousVisibleIndex != nil)
					? max(metrics.tracks[previousVisibleIndex!].gap, 0)
					: 0
				let remaining = max(0, available - position - gap)
				let resolved = min(maximum, remaining)
				if resolved > 0 {
					position += gap
					offsets[index] = position
					lengths[index] = resolved
					position += resolved
					previousVisibleIndex = index
					bandHasVisibleTrack = true
				} else {
					lengths[index] = 0
					offsets[index] = position
				}
				finishBand()

			default:
				let length = max(preparedLengths[index], 0)
				guard length > 0 else {
					lengths[index] = 0
					offsets[index] = position
					continue
				}

				var gap: CGFloat = 0
				if layout == .gaps, let previousVisibleIndex {
					gap = max(metrics.tracks[previousVisibleIndex].gap, 0)
				}
				if bandHasVisibleTrack && position + gap + length > available {
					finishBand()
					bands[index] = band
					gap = 0
				}

				position += gap
				offsets[index] = position
				lengths[index] = length
				position += length
				previousVisibleIndex = index
				bandHasVisibleTrack = true
			}
		}

		if bandHasVisibleTrack || bandSizes.isEmpty {
			bandSizes.append(position)
		} else if bandSizes.last == 0, bandSizes.count > 1 {
			bandSizes.removeLast()
		}

		let wrappedSize = bandSizes.max() ?? 0
		let wrappedMetrics = TrackMetrics(
			tracks: metrics.tracks,
			lengths: lengths,
			offsets: offsets,
			size: wrappedSize
		)
		self.metrics = wrappedMetrics
		return .init(metrics: wrappedMetrics, bands: bands, bandSizes: bandSizes)
	}

	public func apply(
		available: CGFloat = .unbounded,
		intrinsic: (
			_ index: Int,
			_ element: Track,
			_ bound: CGFloat
		) -> CGFloat
	) {
		if let factory, metrics.tracks.isEmpty {
			metrics.tracks = (0..<count).map(factory)
		}
		guard !metrics.tracks.isEmpty else { return }
		prepare(intrinsic)
		calculateFills(available)
	}

	private func prepare(
		_ intrinsic: (
			_ index: Int,
			_ element: Track,
			_ bound: CGFloat
		) -> CGFloat
	) {
		guard preparedLengths.isEmpty else { return }
		self.preparedLengths = Array(repeating: 0, count: metrics.tracks.count)
		var uniform: [CGFloat] = []
		uniform.reserveCapacity(metrics.tracks.count)
		for (index, element) in metrics.tracks.enumerated() {
			switch element.length {
			case .fixed(let length):
				self.preparedLengths[index] = max(0, length)
			case .intrinsic(bound: let bound, min: let minimum):
				var length = intrinsic(index, element, bound)
				length = max(length, minimum ?? 0)
				self.preparedLengths[index] = length
			case .uniform(_):
				var length = intrinsic(index, element, .unbounded)
				length = max(length, 0)
				if length > 0 {
					uniform.append(length)
				}
				self.preparedLengths[index] = length
			case .fill(let fraction, _, let maximum):
				let lockedAtZero = maximum <= 0 || fraction.map { $0 <= 0 } ?? false
				if !lockedAtZero { fillCount += 1 }
				// Fill lengths are resolved only after available space is known.
				self.preparedLengths[index] = 0
			}
		}
		if let first = uniform.first {
			for (index, element) in metrics.tracks.enumerated() {
				switch element.length {
				case .uniform(let reduce):
					let length = uniform.dropFirst().reduce(first) { accume, next in
						next > 0.0 ? reduce(accume, next) : accume
					}
					self.preparedLengths[index] = length
				default:
					break
				}
			}
		}
		metrics.lengths = preparedLengths
		self.preparedSize = calculatePreparedSize()
		self.metrics.size = calculateSize()
	}

	private func calculatePreparedSize() -> CGFloat {
		if layout == .stack {
			return metrics.tracks.indices.reduce(CGFloat.zero) { size, index in
				guard case .fill = metrics.tracks[index].length else {
					return max(size, preparedLengths[index])
				}
				return size
			}
		}

		var size: CGFloat = 0
		var previousVisibleIndex: Int?

		for index in metrics.tracks.indices {
			let visible: Bool
			let nonFillLength: CGFloat

			switch metrics.tracks[index].length {
			case .fill(let fraction, _, let maximum):
				visible = maximum > 0 && (fraction == nil || fraction! > 0)
				nonFillLength = 0
			default:
				nonFillLength = max(preparedLengths[index], 0)
				visible = nonFillLength > 0
			}

			guard visible else { continue }
			if layout == .gaps, let previousVisibleIndex {
				size += max(metrics.tracks[previousVisibleIndex].gap, 0)
			}
			size += nonFillLength
			previousVisibleIndex = index
		}

		return size
	}

	private func calculateSize() -> CGFloat {
		metrics.offsets = Array(repeating: 0, count: metrics.tracks.count)
		if layout == .stack {
			return metrics.lengths.reduce(0, max)
		}
		var size: CGFloat = 0
		var previousVisibleIndex: Int?

		for (index, length) in metrics.lengths.enumerated() {
			if length > 0, layout == .gaps, let previousVisibleIndex {
				size += metrics.tracks[previousVisibleIndex].gap
			}
			metrics.offsets[index] = size
			if length > 0 {
				size += length
				previousVisibleIndex = index
			}
		}

		return size
	}

	private func calculateFills(_ available: CGFloat) {
		guard hasFill else { return }
		guard lastBounds != available else { return }
		lastBounds = available
		metrics.lengths = preparedLengths
		metrics.size = calculateSize()

		if available == .unbounded {
			let allFill = metrics.tracks.allSatisfy { track in
				if case .fill = track.length {
					return true
				}
				return false
			}
			if allFill && metrics.size == 0 {
				metrics.size = 1
			}
			return
		}

		let dftFillFraction = 1.0 / CGFloat(fillCount)
		if layout == .stack {
			for (index, element) in metrics.tracks.enumerated() {
				switch element.length {
				case .fill(let fraction, let minimum, let maximum):
					let lockedAtZero = maximum <= 0 || fraction.map {$0 <= 0} ?? false
					if !lockedAtZero {
						let fraction = fraction.map { $0 >= 0.0 ? $0 : 0.0} ?? dftFillFraction
						let length = max(minimum, min(maximum, fraction * available))
						self.metrics.lengths[index] = length
					}
				default:
					break
				}
			}
		} else {
			var availableFill = max(0, available - preparedSize)
			resetSequentialFills()
			allocateFills(
				availableFill: availableFill,
				fillFraction: dftFillFraction
			)

			var calculatedSize = calculateSize()
			if calculatedSize > available {
				let overflow = calculatedSize - available
				availableFill = max(0, availableFill - overflow)
				resetSequentialFills()
				allocateFills(
					availableFill: availableFill,
					fillFraction: dftFillFraction
				)
				calculatedSize = calculateSize()
			}
			self.metrics.size = calculatedSize
			return
		}
		self.metrics.size = calculateSize()
	}

	private func resetSequentialFills() {
		metrics.lengths = preparedLengths
		for index in metrics.tracks.indices {
			if case .fill = metrics.tracks[index].length {
				metrics.lengths[index] = 0
			}
		}
	}

	private func allocateFills(
		availableFill: CGFloat,
		fillFraction: CGFloat
	) {
		guard availableFill > 0 else { return }
		var remainingFill = availableFill

		for (index, element) in metrics.tracks.enumerated() {
			guard remainingFill > 0 else { break }
			guard case .fill(let fraction, let minimum, let maximum) = element.length else {
				continue
			}

			let lockedAtZero = maximum <= 0 || fraction.map { $0 <= 0 } ?? false
			guard !lockedAtZero else {
				metrics.lengths[index] = 0
				continue
			}

			let requested = max(
				minimum,
				min(maximum, (fraction ?? fillFraction) * availableFill)
			)
			let resolved = min(requested, remainingFill)

			metrics.lengths[index] = resolved
			remainingFill -= resolved
		}
	}
}
