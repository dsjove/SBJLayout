import Foundation
import PDFKit

public struct PDFGenerator {
	public let pageLayout: PageLayout

	public init(
		pageLayout: PageLayout = .init()
	) {
		self.pageLayout = pageLayout
	}

	public func render(_ content: Renderable, jargon: Jargon = .standard, insets: Insets = .zero, _ paging: ((Pagination) -> ())? = nil) -> Data {
		let pageRect = pageLayout.pageSize.rect(landscape: pageLayout.landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		return renderer.pdfData { context in
			let pagination = Pagination(layout: pageLayout, insets: insets) {
				context.beginPage()
				paging?($0)
			}
			RenderableEnvironment.withContext(jargon: jargon, pagination: pagination) {
				let measured = content.measure(bounds: CGSize(fixedWidth: pagination.contentRect.width))
				let allocated = CGRect(origin: pagination.printableRect.origin, size: measured)
				content.render(in: allocated)
			}
		}
	}

	public func form(_ content: Renderable, jargon: Jargon = .standard, insets: Insets = .zero, _ paging: ((Pagination) -> ())? = nil) -> (Data, PDFDocument?) {
		let pdfData: Data = render(content, jargon: jargon, insets: insets, paging)
		return (pdfData, PDFDocument(data: pdfData))
	}
}
