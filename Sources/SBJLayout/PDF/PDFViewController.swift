#if !os(watchOS)
import Observation
import PDFKit

/// SwiftUI-facing controller for the PDFKit view hosted by ``StablePDFView``.
///
/// `PDFView` is deliberately kept behind this type. SwiftUI callers can navigate,
/// observe page state, and ask for converted pagination geometry without depending
/// on UIKit/PDFKit view identity.
@Observable
@MainActor
public final class PDFViewController: PDFPageNavigating, PDFTextSearching {
	public private(set) var currentPage = PDFCurrentPage.empty
	private weak var pdfView: PDFView?
	private var pageChangeTask: Task<Void, Never>?
	private var searchNavigationTask: Task<Void, Never>?
	private var searchMatches: [PDFSearchMatch] = []
	private var currentSearchMatchIndex: Int?
	private var pendingSearchAnchor: SearchAnchor?

	private struct SearchAnchor {
		let pageIndex: Int
		let normalizedCenter: CGPoint
	}

	public let minimumSearchCharacterCount: Int
	public var searchPresentationStyle: PDFSearchPresentationStyle {
		didSet { presentSearchMatches() }
	}

	public init(
		minimumSearchCharacterCount: Int = 2,
		searchPresentationStyle: PDFSearchPresentationStyle = PDFSearchPresentationStyle()
	) {
		self.minimumSearchCharacterCount = max(minimumSearchCharacterCount, 1)
		self.searchPresentationStyle = searchPresentationStyle
	}

	func setDisplayCount(_ count: Int) {
		let displayCount = max(count, 1)
		guard currentPage.displayCount != displayCount else { return }
		currentPage = PDFCurrentPage(
			pageNumber: currentPage.pageNumber,
			displayCount: displayCount,
			pageCount: currentPage.pageCount
		)
	}

	func resetPageState() {
		currentPage = .empty
	}

	public func goToFirstPage() {
		pdfView?.goToFirstPage(nil)
		refreshPageState()
	}

	public func goToPreviousPage() {
		pdfView?.goToPreviousPage(nil)
		refreshPageState()
	}

	public func goToNextPage() {
		pdfView?.goToNextPage(nil)
		refreshPageState()
	}

	public func goToLastPage() {
		pdfView?.goToLastPage(nil)
		refreshPageState()
	}

	/// Whether the shared page/search chrome is currently presenting search controls.
	/// This belongs to the controller rather than SwiftUI local state so changing the
	/// surrounding presentation layout cannot silently exit an active search.
	public var isSearchPresented = false

	public var searchQuery: String = "" {
		didSet {
			guard searchQuery != oldValue else { return }
			rebuildSearchResults(animateFirstMatch: true)
		}
	}

	public var isSearchActive: Bool {
		searchQuery.count >= minimumSearchCharacterCount
	}

	public var searchMatchCount: Int { searchMatches.count }

	public var currentSearchMatchNumber: Int? {
		guard let currentSearchMatchIndex, searchMatches.indices.contains(currentSearchMatchIndex) else {
			return nil
		}
		return currentSearchMatchIndex + 1
	}

	public func goToPreviousSearchMatch() {
		guard !searchMatches.isEmpty else { return }
		let index = currentSearchMatchIndex ?? 0
		selectSearchMatch(at: (index - 1 + searchMatches.count) % searchMatches.count, animated: true)
	}

	public func goToNextSearchMatch() {
		guard !searchMatches.isEmpty else { return }
		let index = currentSearchMatchIndex ?? -1
		selectSearchMatch(at: (index + 1) % searchMatches.count, animated: true)
	}

	public func clearSearch() {
		isSearchPresented = false
		searchNavigationTask?.cancel()
		searchNavigationTask = nil
		searchQuery = ""
		clearSearchResults()
	}

	/// Captures the active result before StablePDFView replaces the document pages.
	/// Search results themselves contain only page-relative geometry, but the query is
	/// rerun afterward because regenerated content may have changed the match set.
	func documentWillChange() {
		searchNavigationTask?.cancel()
		searchNavigationTask = nil
		pendingSearchAnchor = currentSearchAnchor()
		clearSearchResults(preservingAnchor: true)
	}

	/// Rebuilds search geometry after StablePDFView replaces the pages in its
	/// long-lived private display document. An unchanged query preserves the active
	/// result by choosing the new match nearest its previous page-relative position.
	/// The regenerated document's viewport is already restored by StablePDFView, so
	/// this refresh deliberately does not navigate or animate.
	func documentDidChange() {
		rebuildSearchResults(animateFirstMatch: false, restoring: pendingSearchAnchor)
		pendingSearchAnchor = nil
	}

	private func rebuildSearchResults(
		animateFirstMatch: Bool,
		restoring anchor: SearchAnchor? = nil
	) {
		searchNavigationTask?.cancel()
		searchNavigationTask = nil

		guard searchQuery.count >= minimumSearchCharacterCount,
			let document = pdfView?.document
		else {
			clearSearchResults()
			return
		}

		searchMatches = document.findString(searchQuery, withOptions: [.caseInsensitive]).compactMap { selection in
			makeSearchMatch(from: selection, in: document)
		}
		guard !searchMatches.isEmpty else {
			currentSearchMatchIndex = nil
			presentSearchMatches()
			return
		}

		if let anchor, let restoredIndex = nearestSearchMatch(to: anchor, in: document) {
			currentSearchMatchIndex = restoredIndex
		} else {
			currentSearchMatchIndex = 0
		}
		presentSearchMatches()
		if animateFirstMatch {
			navigateToCurrentSearchMatch(animated: true)
		}
	}

	private func clearSearchResults(preservingAnchor: Bool = false) {
		searchMatches.removeAll()
		currentSearchMatchIndex = nil
		if !preservingAnchor { pendingSearchAnchor = nil }
		(pdfView as? FitClampedPDFView)?.clearSearchPresentation()
	}

	private func currentSearchAnchor() -> SearchAnchor? {
		guard let document = pdfView?.document,
			let currentSearchMatchIndex,
			searchMatches.indices.contains(currentSearchMatchIndex),
			let fragment = searchMatches[currentSearchMatchIndex].firstFragment,
			fragment.pageIndex >= 0,
			fragment.pageIndex < document.pageCount,
			let page = document.page(at: fragment.pageIndex)
		else { return nil }

		let pageBounds = page.bounds(for: .cropBox)
		guard !fragment.pageRect.isNull, !pageBounds.isNull, pageBounds.width > 0, pageBounds.height > 0 else { return nil }

		return SearchAnchor(
			pageIndex: fragment.pageIndex,
			normalizedCenter: CGPoint(
				x: (fragment.pageRect.midX - pageBounds.minX) / pageBounds.width,
				y: (fragment.pageRect.midY - pageBounds.minY) / pageBounds.height
			)
		)
	}

	private func nearestSearchMatch(to anchor: SearchAnchor, in document: PDFDocument) -> Int? {
		var best: (index: Int, score: CGFloat)?

		for (index, match) in searchMatches.enumerated() {
			guard let fragment = match.firstFragment,
				fragment.pageIndex >= 0,
				fragment.pageIndex < document.pageCount,
				let page = document.page(at: fragment.pageIndex)
			else { continue }

			let pageBounds = page.bounds(for: .cropBox)
			guard !fragment.pageRect.isNull, !pageBounds.isNull, pageBounds.width > 0, pageBounds.height > 0 else { continue }

			let center = CGPoint(
				x: (fragment.pageRect.midX - pageBounds.minX) / pageBounds.width,
				y: (fragment.pageRect.midY - pageBounds.minY) / pageBounds.height
			)

			let pageDistance = CGFloat(abs(fragment.pageIndex - anchor.pageIndex))
			let dx = center.x - anchor.normalizedCenter.x
			let dy = center.y - anchor.normalizedCenter.y
			let score = pageDistance * 10 + hypot(dx, dy)

			if best == nil || score < best!.score {
				best = (index, score)
			}
		}

		return best?.index
	}

	private func makeSearchMatch(from selection: PDFSelection, in document: PDFDocument) -> PDFSearchMatch? {
		let fragments = selection.selectionsByLine().compactMap { line -> PDFSearchMatch.Fragment? in
			guard let page = line.pages.first else { return nil }
			let pageIndex = document.index(for: page)
			guard pageIndex != NSNotFound else { return nil }
			let pageRect = line.bounds(for: page)
			guard !pageRect.isNull, pageRect.width > 0, pageRect.height > 0 else { return nil }
			return PDFSearchMatch.Fragment(pageIndex: pageIndex, pageRect: pageRect)
		}
		guard !fragments.isEmpty else { return nil }
		return PDFSearchMatch(fragments: fragments)
	}

	private func presentSearchMatches() {
		guard let pdfView = pdfView as? FitClampedPDFView else { return }
		if searchMatches.isEmpty {
			pdfView.clearSearchPresentation()
		} else {
			pdfView.presentSearchMatches(searchMatches, style: searchPresentationStyle)
		}
	}

	private func selectSearchMatch(at index: Int, animated: Bool) {
		guard searchMatches.indices.contains(index) else { return }
		currentSearchMatchIndex = index
		navigateToCurrentSearchMatch(animated: animated)
	}

	private func navigateToCurrentSearchMatch(animated: Bool) {
		guard let pdfView,
			let currentSearchMatchIndex,
			searchMatches.indices.contains(currentSearchMatchIndex)
		else { return }

		let match = searchMatches[currentSearchMatchIndex]
		searchNavigationTask?.cancel()
		guard navigate(to: match, in: pdfView) else { return }

		guard animated else { return }
		let expectedIndex = currentSearchMatchIndex
		searchNavigationTask = Task { @MainActor [weak self, weak pdfView] in
			guard let self, let pdfView else { return }
			await self.waitForSearchNavigationToSettle(match, in: pdfView)
			guard !Task.isCancelled,
				self.pdfView === pdfView,
				self.currentSearchMatchIndex == expectedIndex,
				self.searchMatches.indices.contains(expectedIndex)
			else { return }
			(pdfView as? FitClampedPDFView)?.animateSearchMatch(self.searchMatches[expectedIndex])
		}
	}

	private func navigate(to match: PDFSearchMatch, in pdfView: PDFView) -> Bool {
		guard let document = pdfView.document,
			let fragment = match.firstFragment,
			fragment.pageIndex >= 0,
			fragment.pageIndex < document.pageCount,
			let page = document.page(at: fragment.pageIndex)
		else { return false }

		pdfView.go(to: fragment.pageRect, on: page)
		return true
	}

	private func waitForSearchNavigationToSettle(
		_ match: PDFSearchMatch,
		in pdfView: PDFView
	) async {
		var previousRect: CGRect?
		var stableSamples = 0

		for _ in 0..<30 {
			guard !Task.isCancelled, self.pdfView === pdfView else { return }
			pdfView.layoutIfNeeded()
			guard let rect = viewRect(for: match, in: pdfView),
				rect.intersects(pdfView.bounds)
			else {
				stableSamples = 0
				previousRect = nil
				try? await Task.sleep(for: .milliseconds(16))
				continue
			}

			if let previousRect, rect.isApproximatelyEqual(to: previousRect, tolerance: 0.5) {
				stableSamples += 1
				if stableSamples >= 3 { return }
			} else {
				stableSamples = 0
			}
			previousRect = rect
			try? await Task.sleep(for: .milliseconds(16))
		}
	}

	private func viewRect(for match: PDFSearchMatch, in pdfView: PDFView) -> CGRect? {
		guard let document = pdfView.document else { return nil }
		let rects = match.fragments.compactMap { fragment -> CGRect? in
			guard fragment.pageIndex >= 0,
				fragment.pageIndex < document.pageCount,
				let page = document.page(at: fragment.pageIndex)
			else { return nil }
			return pdfView.convert(fragment.pageRect, from: page)
		}
		guard var union = rects.first else { return nil }
		for rect in rects.dropFirst() { union = union.union(rect) }
		return union
	}


	/// Reveals pagination geometry if needed and returns the visible highlight rectangle
	/// in the hosted PDF view's coordinate space. If the section is already comfortably
	/// visible, no navigation occurs.
	public func reveal(_ position: PaginationPosition) async -> CGRect? {
		guard let pdfView else { return nil }
		pdfView.layoutIfNeeded()

		if let rect = convertedViewRect(for: position, in: pdfView),
			isSufficientlyVisible(rect, in: pdfView)
		{
			return visibleViewRect(for: position, in: pdfView)
		}

		pdfView.go(to: position)
		await waitForNavigationToSettle(to: position, in: pdfView)
		guard !Task.isCancelled, self.pdfView === pdfView else { return nil }
		return visibleViewRect(for: position, in: pdfView)
	}

	/// Returns pagination geometry in the hosted PDF view's coordinate space.
	public func viewRect(for position: PaginationPosition) -> CGRect? {
		guard let pdfView else { return nil }
		return visibleViewRect(for: position, in: pdfView)
	}

	func attach(_ view: PDFView) {
		guard pdfView !== view else {
			refreshPageState()
			return
		}

		pageChangeTask?.cancel()
		pdfView = view
		refreshPageState()
		rebuildSearchResults(animateFirstMatch: false)

		pageChangeTask = Task { @MainActor [weak self, weak view] in
			guard let view else { return }
			for await notification in NotificationCenter.default.notifications(
				named: .PDFViewPageChanged,
				object: view
			) {
				guard !Task.isCancelled,
					let changedView = notification.object as? PDFView,
					changedView === view
				else { continue }
				self?.refreshPageState()
			}
		}
	}

	func detach(_ view: PDFView) {
		guard pdfView === view else { return }
		pageChangeTask?.cancel()
		pageChangeTask = nil
		searchNavigationTask?.cancel()
		searchNavigationTask = nil
		(view as? FitClampedPDFView)?.clearSearchPresentation()
		pdfView = nil
	}

	func refreshPageState() {
		let displayCount = max(currentPage.displayCount, 1)
		guard let pdfView, let document = pdfView.document else {
			currentPage = PDFCurrentPage(
				pageNumber: 0,
				displayCount: displayCount,
				pageCount: 0
			)
			return
		}

		let pageCount = document.pageCount
		guard pageCount > 0 else {
			currentPage = PDFCurrentPage(
				pageNumber: 0,
				displayCount: displayCount,
				pageCount: 0
			)
			return
		}

		let pageNumber = (pdfView.sbjLogicalPageIndex ?? 0) + 1

		currentPage = PDFCurrentPage(
			pageNumber: pageNumber,
			displayCount: displayCount,
			pageCount: pageCount
		)
	}

	private func isSufficientlyVisible(_ rect: CGRect, in pdfView: PDFView) -> Bool {
		let comfort = pdfView.bounds.insetBy(dx: 16, dy: 24)
		guard !comfort.isEmpty else { return false }

		let horizontal: Bool
		if rect.width <= comfort.width {
			horizontal = rect.minX >= comfort.minX && rect.maxX <= comfort.maxX
		} else {
			horizontal = comfort.contains(CGPoint(x: rect.midX, y: comfort.midY))
		}

		let vertical: Bool
		if rect.height <= comfort.height {
			vertical = rect.minY >= comfort.minY && rect.maxY <= comfort.maxY
		} else {
			// An oversized section can never fit completely; seeing its beginning is enough.
			vertical = rect.minY >= comfort.minY && rect.minY <= comfort.maxY
		}

		return horizontal && vertical
	}

	private func waitForNavigationToSettle(
		to position: PaginationPosition,
		in pdfView: PDFView
	) async {
		var previousRect: CGRect?
		var stableSamples = 0

		for _ in 0..<30 {
			guard !Task.isCancelled, self.pdfView === pdfView else { return }
			pdfView.layoutIfNeeded()
			guard let rect = convertedViewRect(for: position, in: pdfView) else { return }

			if let previousRect, rect.isApproximatelyEqual(to: previousRect, tolerance: 0.5) {
				stableSamples += 1
				if stableSamples >= 3 { return }
			} else {
				stableSamples = 0
			}
			previousRect = rect
			try? await Task.sleep(for: .milliseconds(16))
		}
	}

	private func visibleViewRect(for position: PaginationPosition, in pdfView: PDFView) -> CGRect? {
		guard let rect = convertedViewRect(for: position, in: pdfView) else { return nil }
		let visibleRect = rect.intersection(pdfView.bounds).insetBy(dx: -2, dy: -2)
		guard !visibleRect.isNull, visibleRect.width > 1, visibleRect.height > 1 else { return nil }
		return visibleRect
	}

	private func convertedViewRect(for position: PaginationPosition, in pdfView: PDFView) -> CGRect? {
		guard let document = pdfView.document,
			position.pageIndex >= 0,
			position.pageIndex < document.pageCount,
			let page = document.page(at: position.pageIndex),
			position.pageRect.width > 0,
			position.pageRect.height > 0
		else { return nil }

		let pageBounds = page.bounds(for: pdfView.displayBox)
		let normalizedX = (position.frame.minX - position.pageRect.minX) / position.pageRect.width
		let normalizedTop = (position.frame.minY - position.pageRect.minY) / position.pageRect.height
		let normalizedWidth = position.frame.width / position.pageRect.width
		let normalizedHeight = position.frame.height / position.pageRect.height

		let pdfRect = CGRect(
			x: pageBounds.minX + normalizedX * pageBounds.width,
			y: pageBounds.maxY - (normalizedTop + normalizedHeight) * pageBounds.height,
			width: normalizedWidth * pageBounds.width,
			height: normalizedHeight * pageBounds.height
		)
		return pdfView.convert(pdfRect, from: page)
	}
}

private extension CGRect {
	func isApproximatelyEqual(to other: CGRect, tolerance: CGFloat) -> Bool {
		abs(minX - other.minX) <= tolerance
			&& abs(minY - other.minY) <= tolerance
			&& abs(width - other.width) <= tolerance
			&& abs(height - other.height) <= tolerance
	}
}
#endif
