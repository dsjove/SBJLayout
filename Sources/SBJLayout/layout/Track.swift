import CoreGraphics

public struct Track {
	public typealias Aggregate = ([CGFloat]) -> CGFloat?

	public let length: TrackSize
	public let align: Alignment
	public let gap: CGFloat
	/// When wrapping is enabled, ends the current wrapped line after this track
	/// without changing the track's resolved length.
	public let breakAfter: Bool
	public let aggregate: Aggregate

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .left, //Column centric
		gap: CGFloat = 3.0,
		breakAfter: Bool = false,
		aggregate: @escaping Aggregate = { $0.max() }
	) {
		self.length = length
		self.align = align
		self.gap = gap
		self.breakAfter = breakAfter
		self.aggregate = aggregate
	}

	public init(
		_ track: Track,
		aggregate: @escaping Aggregate
	) {
		self.init(
			track.length,
			align: track.align,
			gap: track.gap,
			breakAfter: track.breakAfter,
			aggregate: aggregate
		)
	}
}
