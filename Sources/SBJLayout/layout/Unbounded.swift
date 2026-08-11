import CoreGraphics

public extension CGFloat {
	static let unbounded: CGFloat = CGFloat.greatestFiniteMagnitude

	var isUnbounded: Bool {
		self == .unbounded
	}

	var unboundedDescription: String {
		isUnbounded ? "∞" : "\(self)"
	}
}

public extension CGSize {
	static let unbounded: CGSize = .init(width: CGFloat.unbounded, height: CGFloat.unbounded)

	var isEmpty: Bool {
		width.isZero || height.isZero
	}

	init(fixedWidth: CGFloat) {
		self.init(width: fixedWidth, height: CGFloat.unbounded)
	}

	init(textHeight: CGFloat) {
		self.init(width: CGFloat.unbounded, height: textHeight)
	}

	var unboundedDescription: String {
		"(\(width.unboundedDescription)x\(height.unboundedDescription))"
	}

	func inset(by value: CGFloat) -> CGSize {
		inset(dx: value, dy: value)
	}

	func inset(dx: CGFloat, dy: CGFloat) -> CGSize {
		.init(
			width: width.isUnbounded ? width : width - (dx * 2),
			height: height.isUnbounded ? height : height - (dy * 2))
	}
}

public extension CGRect {
	init(x: CGFloat, y: CGFloat, size: CGSize) {
		self.init(x: x, y: y, width: size.width, height: size.height)
	}

	func reorigin(at point: CGPoint) -> CGRect {
		.init(origin: point, size: size)
	}

	func inset(left: CGFloat, top: CGFloat, right: CGFloat, bottom: CGFloat) -> CGRect {
		.init(
			x: minX.isUnbounded ? minX : minX + left,
			y: minY.isUnbounded ? minY : minY + top,
			width: width.isUnbounded ? width : width - left - right,
			height: height.isUnbounded ? height : height - top - bottom
		)
	}
}
