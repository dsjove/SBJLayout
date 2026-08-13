import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("PageSize")
struct PageSizeTests {
	@Test("Special sizes")
	func specialSizes() {
		#expect(PageSize.zero.size == .zero)
		#expect(PageSize.unbounded.size == .unbounded)
		#expect(PageSize.zero.category == .special)
		#expect(PageSize.unbounded.category == .special)
	}

	@Test("Custom size")
	func customSize() {
		let page = PageSize.custom(width: 500, height: 700)
		#expect(page.size == CGSize(width: 500, height: 700))
		#expect(page.category == .custom)
	}

	@Test("Photo sizes use PDF points")
	func photoSizes() {
		#expect(PageSize.photo4x6.size == CGSize(width: 288, height: 432))
		#expect(PageSize.photo8x10.size == CGSize(width: 576, height: 720))
		#expect(PageSize.photo4x6.category == .photo)
	}

	@Test("Category collections")
	func categories() {
		#expect(PageSize.sizes(in: .northAmerican).contains(.letter))
		#expect(PageSize.sizes(in: .isoA).contains(.a4))
		#expect(PageSize.sizes(in: .photo).contains(.photo5x7))
		#expect(PageSize.sizes(in: .custom).isEmpty)
	}

	@Test("Unbounded remains unbounded after margins")
	func unboundedMargins() {
		let rect = PageSize.unbounded.rect(landscape: false, margin: .init(dx: 10, dy: 20))
		#expect(rect.width.isUnbounded)
		#expect(rect.height.isUnbounded)
	}
}
