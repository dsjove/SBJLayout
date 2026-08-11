import CoreGraphics

public enum Aspect: Int, Sendable, Codable, CustomStringConvertible {
	case fit = 0
	case fill = 1
	case stretch = 2
	case original = 3

	public var description: String {
		switch self {
		case .fit:
			"fit"
		case .fill:
			"fill"
		case .stretch:
			"stretch"
		case .original:
			"original"
		}
	}

	public func apply(size: CGSize, in bounds: CGSize) -> CGSize {
		switch self {
		case .fit, .fill:
			let widthUnbounded = bounds.width.isUnbounded
			let heightUnbounded = bounds.height.isUnbounded
			if widthUnbounded && heightUnbounded {
				return size
			} else if widthUnbounded {
				let scale = bounds.height / size.height
				let w = size.width * scale
				let h = bounds.height
				return .init(width: w, height: h)
			} else if heightUnbounded {
				let scale = bounds.width / size.width
				let w = bounds.width
				let h = size.height * scale
				return .init(width: w, height: h)
			} else {
				let scaleX = bounds.width / size.width
				let scaleY = bounds.height / size.height
				let scale = (self == .fit) ? min(scaleX, scaleY) : max(scaleX, scaleY)
				let w = size.width * scale
				let h = size.height * scale
				return .init(width: w, height: h)
			}
		case .stretch:
			let w = bounds.width.isUnbounded ? size.width : bounds.width
			let h = bounds.height.isUnbounded ? size.height : bounds.height
			return .init(width: w, height: h)
		case .original:
			let w = size.width
			let h = size.height
			return .init(width: w, height: h)
		}
	}
}
