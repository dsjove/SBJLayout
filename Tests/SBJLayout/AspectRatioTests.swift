import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("AspectRatio")
struct AspectRatioTests {
	@Test("Creates sizes from either dimension")
	func sizes() {
		let ratio = AspectRatio(3, 2)
		#expect(ratio.size(width: 300) == CGSize(width: 300, height: 200))
		#expect(ratio.size(height: 200) == CGSize(width: 300, height: 200))
	}

	@Test("Inverse swaps dimensions")
	func inverse() {
		#expect(AspectRatio.threeByTwo.inverse == AspectRatio(2, 3))
	}

	@Test("Fit and fill use the ratio")
	func fitAndFill() {
		let ratio = AspectRatio(2, 1)
		let bounds = CGSize(width: 100, height: 100)
		#expect(ratio.fitting(in: bounds) == CGSize(width: 100, height: 50))
		#expect(ratio.filling(bounds) == CGSize(width: 200, height: 100))
	}
}
