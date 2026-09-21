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
public final class PDFViewController: PDFPageNavigating {
	public private(set) var currentPage = PDFCurrentPage.empty
	private weak var pdfView: PDFView?
	private var pageChangeTask: Task<Void, Never>?

	public init() {}

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
