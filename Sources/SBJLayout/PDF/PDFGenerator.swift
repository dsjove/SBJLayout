import Foundation
import PDFKit

public struct PDFGenerator {
	public let pageSize: PageSize
	public let margin: CGSize //TODO: Make Insets
	public let landscape: Bool

	public init(
		pageSize: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false
	) {
		self.pageSize = pageSize
		self.margin = margin
		self.landscape = landscape
	}

	public func render(_ content: JCSLayoutElement, insets: Insets = .init(), _ paging: ((Pagination) -> ())? = nil) -> Data {
		let pageRect = pageSize.rect(landscape: landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		return renderer.pdfData { context in
			let page = BasicPagination(size: pageSize, margin: margin, insets: insets, landscape: landscape) {
				context.beginPage()
				paging?($0)
			}
			layoutElementPage = page
			let measured = content.measure(bounds: CGSize(fixedWidth: page.contentRect.width))
			let allocated = CGRect(origin: page.printableRect.origin, size: measured)
			content.draw(in: allocated)
		}
	}

	public func form(_ content: JCSLayoutElement, insets: Insets = .init(), _ paging: ((Pagination) -> ())? = nil) -> (Data, PDFDocument?) {
		let pdfData: Data = render(content, insets: insets, paging)
		return (pdfData, PDFDocument(data: pdfData))
	}
}
