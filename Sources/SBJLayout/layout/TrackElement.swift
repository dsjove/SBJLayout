import CoreGraphics

public protocol TrackElement {
	// required content size, do not return unbounded values
	func measure(bounds: CGSize) -> CGSize

	/// Axes on which this element participates in intrinsic track aggregation.
	var measurementAxes: MeasurementAxes { get }
}

public extension TrackElement {
	var measurementAxes: MeasurementAxes { .all }

	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}
}

public struct TrackedElement: TrackElement {
	public let element: any Renderable

	public init(_ element: any Renderable) {
		self.element = element
	}

	public var measurementAxes: MeasurementAxes { element.measurementAxes }

	// see TrackElement
	public func measure(bounds: CGSize) -> CGSize {
		element.measure(bounds: bounds)
	}
}

