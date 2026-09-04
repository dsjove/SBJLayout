import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Aspect")
struct AspectTests {
	private let wide = CGSize(width: 200, height: 100)
	private let square = CGSize(width: 100, height: 100)

	@Test("Fit preserves aspect ratio and stays inside both bounds")
	func fit() {
		#expect(Aspect.fit.apply(size: wide, in: square) == CGSize(width: 100, height: 50))
		#expect(Aspect.fit.apply(size: CGSize(width: 100, height: 200), in: square) == CGSize(width: 50, height: 100))
		#expect(Aspect.fit.apply(size: square, in: CGSize(width: 200, height: 300)) == CGSize(width: 200, height: 200))
	}

	@Test("Fill preserves aspect ratio and covers both bounds")
	func fill() {
		#expect(Aspect.fill.apply(size: wide, in: square) == CGSize(width: 200, height: 100))
		#expect(Aspect.fill.apply(size: CGSize(width: 100, height: 200), in: square) == CGSize(width: 100, height: 200))
		#expect(Aspect.fill.apply(size: square, in: CGSize(width: 200, height: 300)) == CGSize(width: 300, height: 300))
	}

	@Test("Fit and fill derive an unbounded dimension from the bounded dimension")
	func oneUnboundedDimension() {
		for aspect in [Aspect.fit, .fill] {
			#expect(aspect.apply(size: wide, in: CGSize(width: .unbounded, height: 50)) == CGSize(width: 100, height: 50))
			#expect(aspect.apply(size: wide, in: CGSize(width: 80, height: .unbounded)) == CGSize(width: 80, height: 40))
		}
	}

	@Test("Fit and fill preserve the original when both dimensions are unbounded")
	func bothDimensionsUnbounded() {
		#expect(Aspect.fit.apply(size: wide, in: .unbounded) == wide)
		#expect(Aspect.fill.apply(size: wide, in: .unbounded) == wide)
	}

	@Test("Stretch replaces bounded dimensions independently")
	func stretch() {
		#expect(Aspect.stretch.apply(size: wide, in: square) == square)
		#expect(Aspect.stretch.apply(size: wide, in: CGSize(width: 80, height: .unbounded)) == CGSize(width: 80, height: 100))
		#expect(Aspect.stretch.apply(size: wide, in: CGSize(width: .unbounded, height: 50)) == CGSize(width: 200, height: 50))
		#expect(Aspect.stretch.apply(size: wide, in: .unbounded) == wide)
	}

	@Test("Original ignores all bounds")
	func original() {
		#expect(Aspect.original.apply(size: wide, in: square) == wide)
		#expect(Aspect.original.apply(size: wide, in: .zero) == wide)
		#expect(Aspect.original.apply(size: wide, in: .unbounded) == wide)
	}
	@Test("Fit and fill return zero for empty or invalid source geometry")
	func invalidSourceGeometry() {
		for aspect in [Aspect.fit, .fill] {
			#expect(aspect.apply(size: .zero, in: square) == .zero)
			#expect(aspect.apply(size: CGSize(width: 0, height: 100), in: square) == .zero)
			#expect(aspect.apply(size: CGSize(width: 100, height: 0), in: square) == .zero)
			#expect(aspect.apply(size: CGSize(width: -.infinity, height: 100), in: square) == .zero)
		}
	}

}
