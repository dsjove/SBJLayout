import CoreGraphics

public protocol TrackElement {
	// required content size, do not return unbounded values
	func measure(bounds: CGSize) -> CGSize
}

public extension TrackElement {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
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
}

