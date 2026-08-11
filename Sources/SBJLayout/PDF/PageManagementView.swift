import SwiftUI
import PDFKit

public struct PageManagementView: View {
	let document: PDFDocument
	let pdfView: PDFView?

	@State private var currentPageNumber: Int

	//A document that had no 'beginPage' called will still have a page

	public init(document: PDFDocument, pdfView: PDFView?, currentPageNumber: Int = 0) {
		self.document = document
		self.pdfView = pdfView
		self.currentPageNumber = currentPageNumber
	}

	public var pageCount: Int {
		document.pageCount
	}

	private var documentID: ObjectIdentifier {
		ObjectIdentifier(document)
	}

	private var pdfViewID: ObjectIdentifier? {
		pdfView.map(ObjectIdentifier.init)
	}

	public var canGoToPreviousPage: Bool {
		pdfView != nil && currentPageNumber > 1
	}

	public var canGoToNextPage: Bool {
		pdfView != nil && currentPageNumber > 0 && currentPageNumber < pageCount
	}

	public var body: some View {
		HStack(spacing: 8) {
			Button {
				pdfView?.goToFirstPage(nil)
				updateCurrentPage()
			} label: {
				Image(systemName: "backward.end")
			}
			.accessibilityLabel("First Page")
			.disabled(!canGoToPreviousPage)

			Button {
				pdfView?.goToPreviousPage(nil)
				updateCurrentPage()
			} label: {
				Image(systemName: "chevron.left")
			}
			.accessibilityLabel("Previous Page")
			.disabled(!canGoToPreviousPage)

			Text("\(currentPageNumber)/\(pageCount)")
				.monospacedDigit()
				.fixedSize()
				.accessibilityLabel("Page \(currentPageNumber) of \(pageCount)")

			Button {
				pdfView?.goToNextPage(nil)
				updateCurrentPage()
			} label: {
				Image(systemName: "chevron.right")
			}
			.accessibilityLabel("Next Page")
			.disabled(!canGoToNextPage)

			Button {
				pdfView?.goToLastPage(nil)
				updateCurrentPage()
			} label: {
				Image(systemName: "forward.end")
			}
			.accessibilityLabel("Last Page")
			.disabled(!canGoToNextPage)
		}
		.onChange(of: documentID, initial: true) { _, _ in
			updateCurrentPage()
		}
		.onChange(of: pdfViewID, initial: true) { _, _ in
			updateCurrentPage()
		}
		.onReceive(NotificationCenter.default.publisher(for: .PDFViewPageChanged)) { notification in
			guard let changedView = notification.object as? PDFView, changedView === pdfView else { return }
			updateCurrentPage()
		}
	}

	private func updateCurrentPage() {
		guard pageCount > 0 else {
			currentPageNumber = 0
			return
		}

		guard let currentPage = pdfView?.currentPage else {
			// A document with pages will initially display its first page once the PDFView is attached.
			currentPageNumber = 1
			return
		}

		let index = document.index(for: currentPage)
		currentPageNumber = index == NSNotFound ? 1 : index + 1
	}
}
