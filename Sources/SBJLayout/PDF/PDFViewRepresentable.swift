import SwiftUI
import PDFKit

public struct PDFViewRepresentable: UIViewRepresentable {
	public let document: PDFDocument
	public let onChange: @Sendable (PDFView) -> Void

	public init(document: PDFDocument, onChange: @escaping @Sendable (PDFView) -> Void) {
		self.document = document
		self.onChange = onChange
	}

	public final class Coordinator {
		private var observers: [NSObjectProtocol] = []

		func observe(_ view: PDFView, onChange: @Sendable @escaping (PDFView) -> Void) {
			observers.forEach(NotificationCenter.default.removeObserver)
			observers = [
				NotificationCenter.default.addObserver(forName: .PDFViewPageChanged, object: view, queue: .main) { _ in onChange(view) },
				NotificationCenter.default.addObserver(forName: .PDFViewDocumentChanged, object: view, queue: .main) { _ in onChange(view) },
			]
		}

		deinit { observers.forEach(NotificationCenter.default.removeObserver) }
	}

	public func makeCoordinator() -> Coordinator { Coordinator() }

	public func makeUIView(context: Context) -> PDFView {
		let view = PDFView()
		view.autoScales = true
		view.displayMode = .singlePageContinuous
		view.displayDirection = .vertical
		view.displaysPageBreaks = true
		view.document = document
		context.coordinator.observe(view, onChange: onChange)
		onChange(view)
		return view
	}

	public func updateUIView(_ uiView: PDFView, context: Context) {
		if uiView.document !== document { uiView.document = document }
		DispatchQueue.main.async { onChange(uiView) }
	}
}
