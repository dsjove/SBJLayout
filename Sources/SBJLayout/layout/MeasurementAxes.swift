import Foundation

/// Controls which grid measurement axes a renderable is allowed to influence.
/// The renderable is still measured and rendered normally; excluded axes are
/// simply omitted from intrinsic track aggregation.
public struct MeasurementAxes: OptionSet, Sendable, Equatable {
	public let rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public static let width = MeasurementAxes(rawValue: 1 << 0)
	public static let height = MeasurementAxes(rawValue: 1 << 1)
	public static let all: MeasurementAxes = [.width, .height]
	public static let none: MeasurementAxes = []
}
