import CoreGraphics

public protocol TrackElement {
	// Required content size for the supplied bounds; do not return unbounded values.
	func measure(bounds: CGSize) -> CGSize

	// Smallest content-driven size the element can validly occupy under the supplied
	// bounds. The default preserves existing behavior; elements with meaningful
	// minimum-content semantics should override this method.
	func minimumMeasure(bounds: CGSize) -> CGSize
}

public extension TrackElement {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	func minimumMeasure(bounds: CGSize) -> CGSize {
		measure(bounds: bounds)
	}

	func minimumMeasure() -> CGSize {
		minimumMeasure(bounds: .unbounded)
	}
}

public struct TrackedElement: TrackElement {
	public let element: any Renderable

	public init(_ element: any Renderable) {
		self.element = element
	}

	// see TrackElement
	public func measure(bounds: CGSize) -> CGSize {
		element.measure(bounds: bounds)
	}

	public func minimumMeasure(bounds: CGSize) -> CGSize {
		element.minimumMeasure(bounds: bounds)
	}
}

// Adapts any TrackElement so GridLayout's ordinary measurement path recursively
// asks for minimum-content measurements. Used only by Grid.minimumMeasure; it
// deliberately leaves normal GridLayout measurement/caching untouched.
internal struct MinimumTrackElement<Base: TrackElement>: TrackElement {
	let base: Base

	init(_ base: Base) {
		self.base = base
	}

	func measure(bounds: CGSize) -> CGSize {
		base.minimumMeasure(bounds: bounds)
	}
}
