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

public extension PDFRenderResult {
	/// Draws one generated PDF page into an existing Core Graphics context, preserving
	/// the page's aspect ratio and centering it inside `bounds`.
	///
	/// This is useful when another subsystem (for example Quick Look thumbnailing)
	/// supplies the graphics context instead of asking SBJLayout to create a PDF context.
	@discardableResult
	func drawPage(
		_ index: Int,
		in context: CGContext,
		fitting bounds: CGRect
	) -> Bool {
		guard index >= 0,
			let page = document?.page(at: index)
		else { return false }

		let pageBounds = page.bounds(for: .mediaBox)
		guard pageBounds.width > 0, pageBounds.height > 0,
			bounds.width > 0, bounds.height > 0
		else { return false }

		let scale = min(bounds.width / pageBounds.width, bounds.height / pageBounds.height)
		let fittedSize = CGSize(width: pageBounds.width * scale, height: pageBounds.height * scale)
		let origin = CGPoint(
			x: bounds.midX - fittedSize.width / 2,
			y: bounds.midY - fittedSize.height / 2
		)

		context.saveGState()
		defer { context.restoreGState() }

		context.translateBy(x: origin.x, y: origin.y)
		context.scaleBy(x: scale, y: scale)
		context.translateBy(x: -pageBounds.minX, y: -pageBounds.minY)
		page.draw(with: .mediaBox, to: context)
		return true
	}
}
