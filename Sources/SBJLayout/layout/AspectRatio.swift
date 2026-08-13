import CoreGraphics

public struct AspectRatio: Sendable, Codable, Hashable, CustomStringConvertible {
	public let width: CGFloat
	public let height: CGFloat

	public init(width: CGFloat, height: CGFloat) {
		self.width = width
		self.height = height
	}

	public init(_ width: CGFloat, _ height: CGFloat) {
		self.init(width: width, height: height)
	}

	public init(size: CGSize) {
		self.init(width: size.width, height: size.height)
	}

	public var value: CGFloat { width / height }
	public var inverse: AspectRatio { .init(width: height, height: width) }
	public var description: String { "\(width):\(height)" }

	public func size(width: CGFloat) -> CGSize {
		CGSize(width: width, height: width / value)
	}

	public func size(height: CGFloat) -> CGSize {
		CGSize(width: height * value, height: height)
	}

	public func fitting(in bounds: CGSize) -> CGSize {
		Aspect.fit.apply(size: CGSize(width: width, height: height), in: bounds)
	}

	public func filling(_ bounds: CGSize) -> CGSize {
		Aspect.fill.apply(size: CGSize(width: width, height: height), in: bounds)
	}

	public static let square = AspectRatio(1, 1)
	public static let threeByTwo = AspectRatio(3, 2)
	public static let fourByThree = AspectRatio(4, 3)
	public static let fiveByFour = AspectRatio(5, 4)
	public static let sevenByFive = AspectRatio(7, 5)
	public static let fourteenByEleven = AspectRatio(14, 11)
	public static let sixteenByNine = AspectRatio(16, 9)
	public static let sixteenByTen = AspectRatio(16, 10)
}
