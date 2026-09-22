#if !os(watchOS)
import Testing
@testable import SBJLayout

@Suite("PDF presentation layout vocabulary")
struct PDFPresentationLayoutTests {
	@Test("Explicit layouts expose page flow and page count")
	func explicitVocabulary() {
		#expect(PDFPresentationLayout.verticalSinglePage.pageFlow == .verticalScrolling)
		#expect(PDFPresentationLayout.verticalSinglePage.pageDisplay == .singlePage)
		#expect(PDFPresentationLayout.horizontalSinglePage.pageFlow == .horizontalPaging)
		#expect(PDFPresentationLayout.horizontalSinglePage.pageDisplay == .singlePage)
		#expect(PDFPresentationLayout.horizontalTwoPage.pageFlow == .horizontalPaging)
		#expect(PDFPresentationLayout.horizontalTwoPage.pageDisplay == .twoPage)
		#expect(PDFPresentationLayout.adaptive().pageDisplay == nil)
	}
}
#endif
