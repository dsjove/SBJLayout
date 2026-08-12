import CoreGraphics

public struct Insets: Sendable, Codable, CustomStringConvertible {
	public let left: CGFloat
	public let right: CGFloat
	public let top: CGFloat
	public let bottom: CGFloat

	public static let zero: Self = .init()

	public init(
		left: CGFloat = 0,
		right: CGFloat = 0,
		top: CGFloat = 0,
		bottom: CGFloat = 0
	) {
		self.left = left
		self.right = right
		self.top = top
		self.bottom = bottom
	}

	public init(
		dx: CGFloat = 0,
		dy: CGFloat = 0
	) {
		self.init(left: dx, right: dx, top: dy, bottom: dy)
	}

	public var description: String {
		"(left: \(left), right: \(right), top: \(top), bottom: \(bottom))"
	}

	public func apply(to: CGSize, content: (CGSize)->CGSize) -> CGSize {
		apply(to: content(apply(to: to)), inverse: true)
	}

	public func apply(to: CGSize, inverse: Bool = false) -> CGSize {
		let multiplier: CGFloat = inverse ? -1 : 1
		return .init(
			width: to.width.isUnbounded
				? to.width
				: to.width - ((left + right) * multiplier),
			height: to.height.isUnbounded
				? to.height
				: to.height - ((top + bottom) * multiplier)
		)
	}

	public func apply(to: CGRect, inverse: Bool = false) -> CGRect {
		let multiplier: CGFloat = inverse ? -1 : 1
		return to.inset(
			left: left * multiplier,
			top: top * multiplier,
			right: right * multiplier,
			bottom: bottom * multiplier)
	}
}
