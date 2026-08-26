import SwiftUI
import PDFKit

/// Stable SwiftUI ownership for a PDFKit view. The PDFView survives unrelated
/// SwiftUI updates and only receives a new document when document identity changes.
public struct StablePDFView: UIViewRepresentable {
	let document: PDFDocument
	let onViewReady: @MainActor (PDFView) -> Void

	public init(document: PDFDocument, onViewReady: @escaping @MainActor (PDFView) -> Void = { _ in }) {
		self.document = document
		self.onViewReady = onViewReady
	}

	public func makeUIView(context: Context) -> PDFView {
		let view = PDFView()
		view.autoScales = true
		view.displayMode = .singlePageContinuous
		view.displayDirection = .vertical
		view.displaysPageBreaks = true
		view.document = document
		notifyWhenReady(view)
		return view
	}

	public func updateUIView(_ view: PDFView, context: Context) {
		if view.document !== document {
			view.document = document
		}
		notifyWhenReady(view)
	}

	private func notifyWhenReady(_ view: PDFView) {
		let expectedDocument = document
		let onViewReady = onViewReady
		Task { @MainActor in
			// Let UIViewRepresentable finish applying the update and give PDFKit a
			// run-loop turn to build/layout its document view before navigation.
			await Task.yield()
			guard view.document === expectedDocument else { return }
			view.layoutIfNeeded()
			view.layoutDocumentView()
			onViewReady(view)
		}
	}
}

public extension PDFView {
	/// Navigates to pagination geometry recorded in the UIGraphics coordinate space
	/// used to create the PDF, converting it to the PDFPage coordinate space here.
	@MainActor
	func go(to position: PaginationPosition) {
		guard let document,
			position.pageIndex >= 0,
			position.pageIndex < document.pageCount,
			let page = document.page(at: position.pageIndex)
		else { return }

		let bounds = page.bounds(for: displayBox)
		guard position.pageRect.width > 0, position.pageRect.height > 0 else {
			go(to: page)
			return
		}

		let normalizedX = (position.frame.minX - position.pageRect.minX) / position.pageRect.width
		let normalizedTop = (position.frame.minY - position.pageRect.minY) / position.pageRect.height
		let point = CGPoint(
			x: bounds.minX + normalizedX * bounds.width,
			y: bounds.maxY - normalizedTop * bounds.height
		)
		go(to: PDFDestination(page: page, at: point))
	}

	@MainActor
	func go(to sectionID: String?, positions: [String: PaginationPosition]) {
		guard let sectionID, let position = positions[sectionID] else { return }
		go(to: position)
	}
}
