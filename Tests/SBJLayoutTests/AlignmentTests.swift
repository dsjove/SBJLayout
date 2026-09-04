import CoreGraphics
import Testing
import UIKit
@testable import SBJLayout

@Suite("Alignment")
struct AlignmentTests {
	@Test("Predefined alignments contain the expected edges")
	func predefinedValues() {
		#expect(Alignment.centerX == [.left, .right])
		#expect(Alignment.centerY == [.top, .bottom])

		#expect(Alignment.leftTop == [.left, .top])
		#expect(Alignment.leftCenter == [.left, .top, .bottom])
		#expect(Alignment.leftBottom == [.left, .bottom])

		#expect(Alignment.centerTop == [.left, .right, .top])
		#expect(Alignment.center == [.left, .right, .top, .bottom])
		#expect(Alignment.centerBottom == [.left, .right, .bottom])

		#expect(Alignment.rightTop == [.right, .top])
		#expect(Alignment.rightCenter == [.right, .top, .bottom])
		#expect(Alignment.rightBottom == [.right, .bottom])
	}

	@Test("Every horizontal and vertical position is applied independently")
	func applyPositions() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		let size = CGSize(width: 20, height: 10)

		let expected: [(Alignment, CGPoint)] = [
			(.leftTop, CGPoint(x: 10, y: 20)),
			(.leftCenter, CGPoint(x: 10, y: 55)),
			(.leftBottom, CGPoint(x: 10, y: 90)),
			(.centerTop, CGPoint(x: 50, y: 20)),
			(.center, CGPoint(x: 50, y: 55)),
			(.centerBottom, CGPoint(x: 50, y: 90)),
			(.rightTop, CGPoint(x: 90, y: 20)),
			(.rightCenter, CGPoint(x: 90, y: 55)),
			(.rightBottom, CGPoint(x: 90, y: 90)),
		]

		for (alignment, origin) in expected {
			#expect(alignment.apply(size: size, in: rect) == CGRect(origin: origin, size: size))
		}
	}

	@Test("Missing axes default to the leading edge")
	func missingAxesDefaultToLeadingEdge() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		let size = CGSize(width: 20, height: 10)

		#expect(Alignment().apply(size: size, in: rect).origin == CGPoint(x: 10, y: 20))
		#expect(Alignment.top.apply(size: size, in: rect).origin == CGPoint(x: 10, y: 20))
		#expect(Alignment.bottom.apply(size: size, in: rect).origin == CGPoint(x: 10, y: 90))
		#expect(Alignment.left.apply(size: size, in: rect).origin == CGPoint(x: 10, y: 20))
		#expect(Alignment.right.apply(size: size, in: rect).origin == CGPoint(x: 90, y: 20))
	}

	@Test("Alignment does not clamp content larger than its rectangle")
	func oversizedContent() {
		let rect = CGRect(x: 10, y: 20, width: 20, height: 10)
		let size = CGSize(width: 40, height: 30)

		#expect(Alignment.center.apply(size: size, in: rect) == CGRect(x: 0, y: 10, width: 40, height: 30))
		#expect(Alignment.rightBottom.apply(size: size, in: rect) == CGRect(x: -10, y: 0, width: 40, height: 30))
	}

	@Test("Text alignment conversion uses only the horizontal component")
	func textAlignmentConversion() {
		#expect(Alignment(.left) == .leftTop)
		#expect(Alignment(.right) == .rightTop)
		#expect(Alignment(.center) == .centerTop)
		#expect(Alignment(.justified) == .centerTop)
		#expect(Alignment(.natural) == .centerTop)

		#expect(Alignment.leftBottom.textAlignment == .left)
		#expect(Alignment.rightBottom.textAlignment == .right)
		#expect(Alignment.centerBottom.textAlignment == .center)
		#expect(Alignment.top.textAlignment == .left)
	}
}
