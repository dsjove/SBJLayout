import SwiftUI
import PDFKit

/// Stable SwiftUI ownership for PDFKit's interactive `PDFView`.
///
/// UIKit/PDFKit view identity is intentionally contained here. SwiftUI callers
/// interact through ``PDFViewController`` rather than receiving the raw view.
public struct StablePDFView: UIViewRepresentable {
	let document: PDFDocument
	let controller: PDFViewController?
	let onReady: @MainActor () -> Void

	public init(
		document: PDFDocument,
		controller: PDFViewController? = nil,
		onReady: @escaping @MainActor () -> Void = {}
	) {
		self.document = document
		self.controller = controller
		self.onReady = onReady
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(controller: controller)
	}

	public func makeUIView(context: Context) -> PDFView {
		let view = PDFView()
		view.autoScales = true
		view.displayMode = .singlePageContinuous
		view.displayDirection = .vertical
		view.displaysPageBreaks = true
		view.document = document
		controller?.attach(view)
		notifyWhenReady(view)
		return view
	}

	public func updateUIView(_ view: PDFView, context: Context) {
		if context.coordinator.controller !== controller {
			context.coordinator.controller?.detach(view)
			context.coordinator.controller = controller
		}
		if view.document !== document {
			view.document = document
		}
		controller?.attach(view)
		notifyWhenReady(view)
	}

	public static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
		coordinator.controller?.detach(view)
	}

	private func notifyWhenReady(_ view: PDFView) {
		let expectedDocument = document
		let controller = controller
		let onReady = onReady
		Task { @MainActor in
			// Let UIViewRepresentable finish applying the update and give PDFKit a
			// run-loop turn to build/layout its document view before navigation.
			await Task.yield()
			guard view.document === expectedDocument else { return }
			view.layoutIfNeeded()
			view.layoutDocumentView()
			controller?.refreshPageState()
			onReady()
		}
	}

	public final class Coordinator {
		var controller: PDFViewController?

		init(controller: PDFViewController?) {
			self.controller = controller
		}
	}
}

extension PDFView {
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
}
