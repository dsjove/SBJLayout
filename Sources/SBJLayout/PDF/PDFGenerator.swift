import Foundation
import PDFKit

public struct PDFGenerator {
	public let pageSize: PageSize
	public let margin: Insets
	public let landscape: Bool

	public init(
		pageSize: PageSize = PageSize.letter,
		margin: Insets = .init(dx: 18.0, dy: 18.0),
		landscape: Bool = false
	) {
		self.pageSize = pageSize
		self.margin = margin
		self.landscape = landscape
	}

	public func render(_ content: Renderable, jargon: Jargon = .standard, insets: Insets = .zero, _ paging: ((Pagination) -> ())? = nil) -> Data {
		let pageRect = pageSize.rect(landscape: landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		return renderer.pdfData { context in
			let pagination = Pagination(size: pageSize, margin: margin, insets: insets, landscape: landscape) {
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
