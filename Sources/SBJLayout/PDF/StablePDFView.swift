import SwiftUI
import PDFKit

/// Minimal PDFKit bridge whose only job is to keep a `PDFView` attached to one
/// document without resetting it during unrelated SwiftUI updates.
public struct StablePDFView: UIViewRepresentable {
	let document: PDFDocument
	let onViewCreated: (PDFView) -> Void

	public init(document: PDFDocument, onViewCreated: @escaping (PDFView) -> Void) {
		self.document = document
		self.onViewCreated = onViewCreated
	}

	public func makeUIView(context: Context) -> PDFView {
		let view = PDFView()
		view.displayMode = .singlePageContinuous
		view.displayDirection = .vertical
		view.autoScales = true
		view.document = document
		onViewCreated(view)
		return view
	}

	public func updateUIView(_ view: PDFView, context: Context) {
		if view.document !== document { view.document = document }
		onViewCreated(view)
	}
}
