#if !os(watchOS)
import CoreGraphics
import PDFKit

/// A document-independent description of what the user is looking at in a PDFView.
///
/// Regenerated PDFs preserve only viewing state: the visible page/anchor and zoom.
/// Text selection intentionally is not restored across document replacement.
struct PDFViewportState {
	struct Anchor {
		let pageIndex: Int
		let normalizedPoint: CGPoint
	}

	let anchor: Anchor?
	let logicalPageIndex: Int?
	let scaleFactor: CGFloat
	let fitScaleRatio: CGFloat?
	let isAtTopAtFit: Bool
}

@MainActor
extension PDFViewportState {
	static func capture(from pdfView: PDFView) -> PDFViewportState? {
		guard let document = pdfView.document,
			pdfView.bounds.width > 0,
			pdfView.bounds.height > 0
		else { return nil }

		let center = CGPoint(x: pdfView.bounds.midX, y: pdfView.bounds.midY)
		let anchor = captureAnchor(at: center, from: pdfView, document: document)

		let fitScale = pdfView.scaleFactorForSizeToFit
		let fitScaleRatio: CGFloat? = if fitScale.isFinite, fitScale > 0 {
			pdfView.scaleFactor / fitScale
		} else {
			nil
		}

		let isAtTopAtFit = captureTopAtFit(from: pdfView, fitScale: fitScale)
		let logicalPageIndex = captureLogicalPageIndex(from: pdfView, document: document, anchor: anchor)

		return PDFViewportState(
			anchor: anchor,
			logicalPageIndex: logicalPageIndex,
			scaleFactor: pdfView.scaleFactor,
			fitScaleRatio: fitScaleRatio,
			isAtTopAtFit: isAtTopAtFit
		)
	}


	private static func captureLogicalPageIndex(
		from pdfView: PDFView,
		document: PDFDocument,
		anchor: Anchor?
	) -> Int? {
		if pdfView.isUsingPageViewController {
			let visibleIndices = pdfView.visiblePages.compactMap { page -> Int? in
				let index = document.index(for: page)
				return index == NSNotFound ? nil : index
			}
			if let firstVisible = visibleIndices.min() { return firstVisible }
		}

		if let anchor { return anchor.pageIndex }
		if let currentPage = pdfView.currentPage {
			let index = document.index(for: currentPage)
			return index == NSNotFound ? nil : index
		}
		return nil
	}

	private static func captureTopAtFit(from pdfView: PDFView, fitScale: CGFloat) -> Bool {
		guard fitScale.isFinite, fitScale > 0,
			abs(pdfView.scaleFactor - fitScale) <= 0.001
		else { return false }

		if pdfView.isUsingPageViewController {
			guard let document = pdfView.document, let currentPage = pdfView.currentPage else { return false }
			return document.index(for: currentPage) == 0
		}

		guard let scrollView = pdfView.sbjScrollView else { return false }
		let minimumY = -scrollView.adjustedContentInset.top
		return abs(scrollView.contentOffset.y - minimumY) <= 1
	}

	private static func captureAnchor(
		at point: CGPoint,
		from pdfView: PDFView,
		document: PDFDocument
	) -> Anchor? {
		guard let page = pdfView.page(for: point, nearest: true) else { return nil }
		let pageIndex = document.index(for: page)
		guard pageIndex != NSNotFound else { return nil }

		let bounds = page.bounds(for: pdfView.displayBox)
		guard bounds.width > 0, bounds.height > 0 else { return nil }
		let pagePoint = pdfView.convert(point, to: page)
		let normalized = CGPoint(
			x: (pagePoint.x - bounds.minX) / bounds.width,
			y: (pagePoint.y - bounds.minY) / bounds.height
		)
		return Anchor(pageIndex: pageIndex, normalizedPoint: normalized)
	}
}
#endif
