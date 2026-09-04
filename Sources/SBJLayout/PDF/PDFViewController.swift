import Observation
import PDFKit

/// SwiftUI-facing controller for the PDFKit view hosted by ``StablePDFView``.
///
/// `PDFView` is deliberately kept behind this type. SwiftUI callers can navigate,
/// observe page state, and ask for converted pagination geometry without depending
/// on UIKit/PDFKit view identity.
@Observable
@MainActor
public final class PDFViewController {
	public private(set) var currentPageNumber = 0
	public private(set) var pageCount = 0

	private weak var pdfView: PDFView?
	private var pageChangeTask: Task<Void, Never>?

	public init() {}
	public var canGoToPreviousPage: Bool {
		pdfView != nil && currentPageNumber > 1
	}

	public var canGoToNextPage: Bool {
		pdfView != nil && currentPageNumber > 0 && currentPageNumber < pageCount
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

	/// Navigates to pagination geometry and returns that geometry in the hosted
	/// PDF view's coordinate space after PDFKit navigation has visually settled.
	///
	/// PDFKit does not expose a destination-navigation completion callback, so the
	/// bridge samples the converted rectangle until it is stable for a few frames.
	public func go(to position: PaginationPosition) async -> CGRect? {
		guard let pdfView else { return nil }
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
		currentPageNumber = 0
		pageCount = 0
	}

	func refreshPageState() {
		guard let pdfView, let document = pdfView.document else {
			currentPageNumber = 0
			pageCount = 0
			return
		}

		pageCount = document.pageCount
		guard pageCount > 0 else {
			currentPageNumber = 0
			return
		}

		guard let currentPage = pdfView.currentPage else {
			currentPageNumber = 1
			return
		}

		let index = document.index(for: currentPage)
		currentPageNumber = index == NSNotFound ? 1 : index + 1
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
