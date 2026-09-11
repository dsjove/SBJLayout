#if !os(watchOS)
import PDFKit
import SwiftUI

/// Displays a fixed number of PDF pages side-by-side using one reusable presentation type.
/// Set `pagesPerView` to 1 for a single-page reader, 2 for facing pages, or a larger value
/// for wider page groups.
@MainActor
public struct PDFPagedView: View {
	private let document: PDFDocument
	private let controller: PDFPagedViewController
	private let pagesPerView: Int

	public init(
		document: PDFDocument,
		controller: PDFPagedViewController,
		pagesPerView: Int = 1
	) {
		self.document = document
		self.controller = controller
		self.pagesPerView = max(1, pagesPerView)
	}

	public var body: some View {
		HStack(spacing: 0) {
			ForEach(0..<pagesPerView, id: \.self) { offset in
				if offset > 0 {
					Divider()
				}
				page(at: controller.firstPageIndex + offset)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			}
		}
		.onAppear {
			controller.update(document: document, pagesPerView: pagesPerView)
		}
		.onChange(of: ObjectIdentifier(document)) { _, _ in
			controller.update(document: document, pagesPerView: pagesPerView)
		}
		.onChange(of: pagesPerView) { _, value in
			controller.update(document: document, pagesPerView: value)
		}
	}

	@ViewBuilder
	private func page(at index: Int) -> some View {
		if index < document.pageCount {
			PDFPageView(document: document, pageIndex: index)
		} else {
			Color.clear
		}
	}
}
#endif
