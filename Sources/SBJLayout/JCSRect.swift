import CoreGraphics
import UIKit

//TODO: API - this is more of a drawing trait than an entity and not a rectangle
public struct JCSRect {
	public let fill: UIColor
	public let stroke: UIColor
	public let lineWidth: CGFloat
	public let radius: CGFloat

	public init(
		fill: UIColor = .clear,
		stroke: UIColor = .clear,
		lineWidth: CGFloat = 1.0,
		radius: CGFloat = 0.0
	) {
		self.fill = fill
		self.stroke = stroke
		self.lineWidth = lineWidth
		self.radius = radius
	}

	@discardableResult
	public func draw(in rect: CGRect) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let path = UIBezierPath(borderRect: rect, cornerRadius: radius)
		path.fill()
		path.stroke()
		return rect
	}

	@discardableResult
	public func draw(center: CGPoint) -> CGRect {
		fill.setFill()
		stroke.setStroke()
		let rect = CGRect(
				x: center.x - radius,
				y: center.y - radius,
				width: radius * 2,
				height: radius * 2
			)
		let path = UIBezierPath(ovalIn: rect)
		path.fill()
		path.stroke()
		return rect
	}
}

//TODO: API - see JCSRect comment
public struct JCSLine {
	public let stroke: UIColor
	public let lineWidth: CGFloat

	public init(stroke: UIColor, lineWidth: CGFloat) {
		self.stroke = stroke
		self.lineWidth = lineWidth
	}

	@discardableResult
	public func draw(from: CGPoint, to: CGPoint) -> CGRect {
		stroke.setStroke()
		let path = UIBezierPath()
		path.move(to: from)
		path.addLine(to: to)
		path.lineWidth = lineWidth
		path.stroke()
		return CGRect(x: min(from.x, to.x), y: min(from.y, to.y), width: abs(from.x - to.x), height: abs(from.y - to.y))
	}
}
