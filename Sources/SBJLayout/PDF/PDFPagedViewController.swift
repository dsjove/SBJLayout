#if !os(watchOS)
import Observation
import PDFKit

/// Navigation state for a PDF presentation that displays a fixed number of pages at once.
///
/// `pagesPerView` is data, not a presentation type: the same controller supports one-page,
/// two-page, and wider page groups without introducing parallel controller classes.
@Observable
@MainActor
public final class PDFPagedViewController: PDFPageNavigating {
	public private(set) var firstPageIndex = 0
	public private(set) var pageCount = 0
	public private(set) var pagesPerView: Int

	public init(pagesPerView: Int = 1) {
		self.pagesPerView = max(1, pagesPerView)
	}

	public var canGoBackward: Bool { firstPageIndex > 0 }
	public var canGoForward: Bool { firstPageIndex + pagesPerView < pageCount }

	public var pageLabel: String {
		guard pageCount > 0 else { return "" }
		let first = firstPageIndex + 1
		let last = min(firstPageIndex + pagesPerView, pageCount)
		return first == last ? "\(first)/\(pageCount)" : "\(first)–\(last)/\(pageCount)"
	}

	public var pageAccessibilityLabel: String {
		guard pageCount > 0 else { return "No pages" }
		let first = firstPageIndex + 1
		let last = min(firstPageIndex + pagesPerView, pageCount)
		return first == last
			? "Page \(first) of \(pageCount)"
			: "Pages \(first) through \(last) of \(pageCount)"
	}

	public func update(document: PDFDocument?, pagesPerView newPagesPerView: Int? = nil) {
		let newCount = document?.pageCount ?? 0
		let normalizedPagesPerView = max(1, newPagesPerView ?? pagesPerView)
		guard newCount != pageCount || normalizedPagesPerView != pagesPerView else { return }

		pageCount = newCount
		pagesPerView = normalizedPagesPerView
		firstPageIndex = normalizedGroupIndex(firstPageIndex)
	}

	public func goToFirstPage() {
		firstPageIndex = 0
	}

	public func goToPreviousPage() {
		firstPageIndex = max(firstPageIndex - pagesPerView, 0)
	}

	public func goToNextPage() {
		guard pageCount > 0 else { return }
		firstPageIndex = min(firstPageIndex + pagesPerView, normalizedGroupIndex(pageCount - 1))
	}

	public func goToLastPage() {
		guard pageCount > 0 else { return }
		firstPageIndex = normalizedGroupIndex(pageCount - 1)
	}

	private func normalizedGroupIndex(_ index: Int) -> Int {
		guard pageCount > 0 else { return 0 }
		let clamped = min(max(index, 0), pageCount - 1)
		return clamped - (clamped % pagesPerView)
	}
}
#endif
