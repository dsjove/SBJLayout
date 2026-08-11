import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Insets")
struct InsetsTests {
	private let insets = Insets(left: 1, right: 2, top: 3, bottom: 4)

	@Test("Default initializer creates zero insets")
	func defaultInitializer() {
		let insets = Insets()
		#expect(insets.left == 0)
		#expect(insets.right == 0)
		#expect(insets.top == 0)
		#expect(insets.bottom == 0)
	}

	@Test("Applying to a size removes each edge exactly once")
	func applySize() {
		let size = CGSize(width: 20, height: 30)
		#expect(insets.apply(to: size) == CGSize(width: 17, height: 23))
	}

	@Test("Inverse size application restores each edge exactly once")
	func inverseSize() {
		let size = CGSize(width: 20, height: 30)
		#expect(insets.apply(to: size, inverse: true) == CGSize(width: 23, height: 37))
		#expect(insets.apply(to: insets.apply(to: size), inverse: true) == size)
	}

	@Test("Applying to a rectangle adjusts its origin and opposite edges")
	func applyRect() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		#expect(insets.apply(to: rect) == CGRect(x: 11, y: 23, width: 97, height: 73))
	}

	@Test("Inverse rectangle application expands around the same edges")
	func inverseRect() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		#expect(insets.apply(to: rect, inverse: true) == CGRect(x: 9, y: 17, width: 103, height: 87))
		#expect(insets.apply(to: insets.apply(to: rect), inverse: true) == rect)
	}

	@Test("Unbounded size dimensions remain unbounded")
	func unboundedSize() {
		#expect(insets.apply(to: CGSize(width: .unbounded, height: 30)) == CGSize(width: .unbounded, height: 23))
		#expect(insets.apply(to: CGSize(width: 20, height: .unbounded), inverse: true) == CGSize(width: 23, height: .unbounded))
	}

	@Test("Zero insets leave sizes and rectangles unchanged")
	func zeroInsets() {
		let size = CGSize(width: 20, height: 30)
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		let zero = Insets()

		#expect(zero.apply(to: size) == size)
		#expect(zero.apply(to: size, inverse: true) == size)
		#expect(zero.apply(to: rect) == rect)
		#expect(zero.apply(to: rect, inverse: true) == rect)
	}
}
