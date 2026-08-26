import Foundation
import PDFKit

public struct PDFRenderResult {
	public let data: Data
	public let document: PDFDocument?
	public let positions: [String: PaginationPosition]

	public init(data: Data, document: PDFDocument?, positions: [String: PaginationPosition]) {
		self.data = data
		self.document = document
		self.positions = positions
	}
}

public struct PDFGenerator {
	public let pageLayout: PageLayout

	public init(
		pageLayout: PageLayout = .init()
	) {
		self.pageLayout = pageLayout
	}

	public func render(_ content: Renderable, jargon: Jargon = .standard, insets: Insets = .zero, _ paging: ((Pagination) -> ())? = nil) -> Data {
		renderResult(content, jargon: jargon, insets: insets, paging).data
	}

	public func form(_ content: Renderable, jargon: Jargon = .standard, insets: Insets = .zero, _ paging: ((Pagination) -> ())? = nil) -> PDFRenderResult {
		let rendered = renderResult(content, jargon: jargon, insets: insets, paging)
		return PDFRenderResult(
			data: rendered.data,
			document: PDFDocument(data: rendered.data),
			positions: rendered.positions
		)
	}

	private func renderResult(
		_ content: Renderable,
		jargon: Jargon,
		insets: Insets,
		_ paging: ((Pagination) -> ())?
	) -> (data: Data, positions: [String: PaginationPosition]) {
		let pageRect = pageLayout.pageSize.rect(landscape: pageLayout.landscape, margin: .zero)
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
		var positions: [String: PaginationPosition] = [:]
		let data = renderer.pdfData { context in
			let pagination = Pagination(layout: pageLayout, insets: insets) {
				context.beginPage()
				paging?($0)
			}
			RenderableEnvironment.withContext(jargon: jargon, pagination: pagination) {
				let measured = content.measure(bounds: CGSize(fixedWidth: pagination.contentRect.width))
				let allocated = CGRect(origin: pagination.printableRect.origin, size: measured)
				content.render(in: allocated)
			}
			positions = pagination.positions
		}
		return (data, positions)
	}
}
