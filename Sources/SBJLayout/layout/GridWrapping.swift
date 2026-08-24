import CoreGraphics

public enum GridWrapping: Sendable {
	case none
	case horizontal
	case vertical
}

internal struct WrappedTrackMetrics {
	let metrics: TrackMetrics
	let bands: [Int]
	let bandSizes: [CGFloat]

	var bandCount: Int { bandSizes.count }
}
