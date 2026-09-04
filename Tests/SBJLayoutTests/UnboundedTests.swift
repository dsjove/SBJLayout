import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Unbounded")
struct UnboundedTests {
	@Test("Only the sentinel CGFloat is unbounded")
	func scalarValues() {
		#expect(CGFloat.unbounded == CGFloat.greatestFiniteMagnitude)
		#expect(CGFloat.unbounded.isUnbounded)
		#expect(!CGFloat(0).isUnbounded)
		#expect(!CGFloat.infinity.isUnbounded)
		#expect(!(-CGFloat.unbounded).isUnbounded)
	}

	@Test("CGSize convenience values set the intended dimensions")
	func sizeValues() {
		#expect(CGSize.unbounded == CGSize(width: .unbounded, height: .unbounded))
		#expect(CGSize(fixedWidth: 25) == CGSize(width: 25, height: .unbounded))
		#expect(CGSize(textHeight: 12) == CGSize(width: .unbounded, height: 12))
	}

	@Test("A size is empty when either dimension is zero")
	func emptySize() {
		#expect(CGSize.zero.isEmpty)
		#expect(CGSize(width: 0, height: 10).isEmpty)
		#expect(CGSize(width: 10, height: 0).isEmpty)
		#expect(!CGSize(width: 10, height: 10).isEmpty)
		#expect(!CGSize(width: -10, height: 10).isEmpty)
		#expect(!CGSize.unbounded.isEmpty)
	}

	@Test("Uniform size inset removes the value from both sides")
	func uniformSizeInset() {
		#expect(CGSize(width: 20, height: 30).inset(by: 2) == CGSize(width: 16, height: 26))
		#expect(CGSize(width: 20, height: 30).inset(by: -2) == CGSize(width: 24, height: 34))
	}

	@Test("Independent size inset applies twice per axis")
	func independentSizeInset() {
		#expect(CGSize(width: 20, height: 30).inset(dx: 2, dy: 3) == CGSize(width: 16, height: 24))
		#expect(CGSize(width: 20, height: 30).inset(dx: -2, dy: -3) == CGSize(width: 24, height: 36))
	}

	@Test("Size inset preserves each unbounded dimension")
	func unboundedSizeInset() {
		#expect(CGSize(width: .unbounded, height: 30).inset(dx: 2, dy: 3) == CGSize(width: .unbounded, height: 24))
		#expect(CGSize(width: 20, height: .unbounded).inset(dx: 2, dy: 3) == CGSize(width: 16, height: .unbounded))
		#expect(CGSize.unbounded.inset(by: 2) == .unbounded)
	}

	@Test("Rectangle convenience initializer preserves origin and size")
	func rectInitializer() {
		#expect(CGRect(x: 10, y: 20, size: CGSize(width: 30, height: 40)) == CGRect(x: 10, y: 20, width: 30, height: 40))
	}

	@Test("Rectangle inset handles four independent edges")
	func rectInset() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		#expect(rect.inset(left: 1, top: 3, right: 2, bottom: 4) == CGRect(x: 11, y: 23, width: 97, height: 73))
	}

	@Test("Negative rectangle inset values expand each edge")
	func inverseRectInset() {
		let rect = CGRect(x: 10, y: 20, width: 100, height: 80)
		#expect(rect.inset(left: -1, top: -3, right: -2, bottom: -4) == CGRect(x: 9, y: 17, width: 103, height: 87))
	}

	@Test("Rectangle inset preserves unbounded dimensions")
	func unboundedRectInset() {
		let rect = CGRect(x: 10, y: 20, width: .unbounded, height: .unbounded)
		let result = rect.inset(left: 1, top: 3, right: 2, bottom: 4)

		#expect(result.origin == CGPoint(x: 11, y: 23))
		#expect(result.size == .unbounded)
	}
}
