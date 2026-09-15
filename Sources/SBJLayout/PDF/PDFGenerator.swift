#if !os(watchOS)
import Foundation
import SBJFoundation
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
	public let title: String?
	public let creator: String?

	public init(
		pageLayout: PageLayout = .init(),
		title: String? = nil,
		creator: String? = nil
	) {
		self.pageLayout = pageLayout
		self.title = title
		self.creator = creator
	}

	public func render(
		_ content: Renderable,
		jargon: Jargon = .standard,
		chrome: PageChrome = .none,
		pages: Range<Int>? = nil,
		_ paging: ((Pagination) -> ())? = nil
	) -> Data {
		renderResult(
			content,
			jargon: jargon,
			chrome: chrome,
			pages: pages,
			paging
		).data
	}

	public func form(
		_ content: Renderable,
		jargon: Jargon = .standard,
		chrome: PageChrome = .none,
		pages: Range<Int>? = nil,
		_ paging: ((Pagination) -> ())? = nil
	) -> PDFRenderResult {
		let rendered = renderResult(
			content,
			jargon: jargon,
			chrome: chrome,
			pages: pages,
			paging
		)
		return PDFRenderResult(
			data: rendered.data,
			document: PDFDocument(data: rendered.data),
			positions: rendered.positions
		)
	}

	private func renderResult(
		_ content: Renderable,
		jargon: Jargon,
		chrome: PageChrome,
		pages: Range<Int>?,
		_ paging: ((Pagination) -> ())?
	) -> (data: Data, positions: [String: PaginationPosition]) {
		let resolved = resolve(chrome: chrome, jargon: jargon)
		let effectiveInsets = Insets(
			left: chrome.contentInsets.left,
			right: chrome.contentInsets.right,
			top: chrome.contentInsets.top
				+ (resolved.headerMeasured?.height ?? 0)
				+ (chrome.header == nil ? 0 : chrome.headerGap),
			bottom: chrome.contentInsets.bottom
				+ (resolved.footerMeasured?.height ?? 0)
				+ (chrome.footer == nil ? 0 : chrome.footerGap)
		)

		let pageRect = pageLayout.pageRect
		let format = UIGraphicsPDFRendererFormat()
		var documentInfo: [String: Any] = [:]
		if let title { documentInfo[kCGPDFContextTitle as String] = title }
		if let creator { documentInfo[kCGPDFContextCreator as String] = creator }
		format.documentInfo = documentInfo
		let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
		var positions: [String: PaginationPosition] = [:]

		let data = renderer.pdfData { context in
			var openPage: PageContext?
			let pagination = Pagination(
				layout: pageLayout,
				insets: effectiveInsets,
				pages: pages
			) { pagination in
				if let previousPage = openPage {
					withPage(previousPage) {
						render(chrome.overlay, in: resolved.printableRect)
					}
				}

				context.beginPage()
				let currentPage = pagination.currentPageContext
				openPage = currentPage

				withPage(currentPage) {
					render(chrome.background, in: resolved.printableRect)
					if let header = chrome.header,
						let rect = resolved.headerRect,
						let measured = resolved.headerMeasured
					{
						header.render(in: rect, measured: measured, align: .leftTop)
					}
					if let footer = chrome.footer,
						let rect = resolved.footerRect,
						let measured = resolved.footerMeasured
					{
						footer.render(in: rect, measured: measured, align: .leftTop)
					}
					paging?(pagination)
				}
			}

			RenderableEnvironment.withContext(jargon: jargon, pagination: pagination) {
				let measured = content.measure(bounds: CGSize(fixedWidth: pagination.contentRect.width))
				let allocated = CGRect(origin: pagination.printableRect.origin, size: measured)
				content.render(in: allocated)

				if let openPage {
					withPage(openPage) {
						render(chrome.overlay, in: resolved.printableRect)
					}
				}
			}
			positions = pagination.positions
		}
		return (data, positions)
	}

	private func resolve(chrome: PageChrome, jargon: Jargon) -> ResolvedPageChrome {
		let pageRect = pageLayout.pageRect
		let printableRect = pageLayout.printableRect
		let chromeRect = chrome.contentInsets.apply(to: printableRect)
		let measurementPagination = Pagination(layout: pageLayout, insets: chrome.contentInsets)

		return RenderableEnvironment.withContext(jargon: jargon, pagination: measurementPagination) {
			let width = chromeRect.width
			let headerMeasured = chrome.header?.measure(bounds: CGSize(fixedWidth: width))
			let footerMeasured = chrome.footer?.measure(bounds: CGSize(fixedWidth: width))
			let headerHeight = headerMeasured?.height ?? 0
			let footerHeight = footerMeasured?.height ?? 0
			let headerGap = chrome.header == nil ? 0 : chrome.headerGap
			let footerGap = chrome.footer == nil ? 0 : chrome.footerGap

			let headerRect = headerMeasured.map { measured in
				CGRect(
					x: chromeRect.minX,
					y: chromeRect.minY,
					width: chromeRect.width,
					height: measured.height
				)
			}
			let footerRect = footerMeasured.map { measured in
				CGRect(
					x: chromeRect.minX,
					y: chromeRect.maxY - measured.height,
					width: chromeRect.width,
					height: measured.height
				)
			}
			let contentRect = CGRect(
				x: chromeRect.minX,
				y: chromeRect.minY + headerHeight + headerGap,
				width: chromeRect.width,
				height: max(0, chromeRect.height - headerHeight - headerGap - footerGap - footerHeight)
			)

			return ResolvedPageChrome(
				pageRect: pageRect,
				printableRect: printableRect,
				chromeRect: chromeRect,
				contentRect: contentRect,
				headerRect: headerRect,
				footerRect: footerRect,
				headerMeasured: headerMeasured,
				footerMeasured: footerMeasured
			)
		}
	}

	private func render(_ chrome: (any Chrome)?, in rect: CGRect) {
		chrome?.render(in: rect, measured: rect.size, align: .leftTop)
	}

	private func withPage<Result>(_ page: PageContext?, operation: () -> Result) -> Result {
		guard let page else { return operation() }
		return RenderableEnvironment.withContext(
			RenderableEnvironment.context.with(page: page),
			operation: operation
		)
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
#endif
