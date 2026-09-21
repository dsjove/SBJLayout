#if !os(watchOS)
import SwiftUI
import UIKit
import PDFKit
import QuartzCore

/// Stable SwiftUI ownership for one long-lived interactive PDFKit `PDFView`.
///
/// The UIKit view survives PDF regeneration. Replacing the PDF payload preserves the user's
/// zoom and viewport anchor while PDFKit updates the attached document in place.
public struct StablePDFView: UIViewRepresentable {
	let document: PDFDocument
	let controller: PDFViewController?
	let layout: PDFContinuousLayout
	let onReady: @MainActor () -> Void

	public init(
		document: PDFDocument,
		controller: PDFViewController? = nil,
		layout: PDFContinuousLayout = .singlePage,
		onReady: @escaping @MainActor () -> Void = {}
	) {
		self.document = document
		self.controller = controller
		self.layout = layout
		self.onReady = onReady
	}

	public func makeCoordinator() -> Coordinator {
		Coordinator(controller: controller)
	}

	public func makeUIView(context: Context) -> StablePDFHostView {
		let host = StablePDFHostView()
		let initialPageIndex = max((controller?.currentPage.pageNumber ?? 1) - 1, 0)
		host.setDisplayCountChangeHandler { count in
			controller?.setDisplayCount(count)
		}
		host.setContinuousLayout(layout)
		context.coordinator.host = host
		controller?.attach(host.pdfView)
		host.installInitial(document: document, pageIndex: initialPageIndex) {
			guard host.represents(document) else { return }
			controller?.refreshPageState()
			onReady()
		}
		return host
	}

	public func updateUIView(_ host: StablePDFHostView, context: Context) {
		if context.coordinator.controller !== controller {
			context.coordinator.controller?.detach(host.pdfView)
			context.coordinator.controller = controller
		}
		context.coordinator.host = host
		host.setDisplayCountChangeHandler { count in
			controller?.setDisplayCount(count)
		}
		controller?.attach(host.pdfView)
		host.setContinuousLayout(layout)

		guard !host.represents(document) else {
			host.pdfView.sbjClampMinimumScaleToFit()
			return
		}

		host.replaceDocument(with: document) {
			guard host.represents(document) else { return }
			controller?.refreshPageState()
			onReady()
		}
	}

	public static func dismantleUIView(_ host: StablePDFHostView, coordinator: Coordinator) {
		coordinator.controller?.detach(host.pdfView)
		coordinator.host = nil
	}

	public final class Coordinator {
		var controller: PDFViewController?
		weak var host: StablePDFHostView?

		init(controller: PDFViewController?) {
			self.controller = controller
		}
	}
}

/// UIKit container that keeps a single PDFView alive while PDF documents are replaced.
@MainActor
public final class StablePDFHostView: UIView {
	let pdfView = FitClampedPDFView()

	private var pendingInitialDocument: PDFDocument?
	private var pendingInitialPageIndex = 0
	private var initialCompletion: (() -> Void)?
	private var replacementGeneration = UUID()
	private var hasPresentedDocument = false
	private var continuousLayout: PDFContinuousLayout = .singlePage
	private var lastViewportSize: CGSize = .zero
	private var isPerformingDocumentTransaction = false
	private var onDisplayCountChange: @MainActor (Int) -> Void = { _ in }
	private var reportedDisplayCount = 1
	private weak var representedSourceDocument: PDFDocument?

	override public init(frame: CGRect) {
		super.init(frame: frame)
		configure()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		configure()
	}

	private func configure() {
		clipsToBounds = true
		pdfView.translatesAutoresizingMaskIntoConstraints = false
		pdfView.autoScales = true
		pdfView.displayMode = .singlePageContinuous
		pdfView.displayDirection = .vertical
		pdfView.displaysAsBook = false
		pdfView.displaysPageBreaks = false
		pdfView.alpha = 0
		addSubview(pdfView)
		NSLayoutConstraint.activate([
			pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
			pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
			pdfView.topAnchor.constraint(equalTo: topAnchor),
			pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),
		])

	}

	override public func layoutSubviews() {
		let viewportWillChange = hasPresentedDocument
			&& !isPerformingDocumentTransaction
			&& lastViewportSize != bounds.size
		let preservedViewport = viewportWillChange ? PDFViewportState.capture(from: pdfView) : nil

		super.layoutSubviews()
		guard bounds.width > 0, bounds.height > 0 else { return }

		if let pendingInitialDocument {
			self.pendingInitialDocument = nil
			let pageIndex = pendingInitialPageIndex
			let completion = initialCompletion
			initialCompletion = nil
			presentInitial(document: pendingInitialDocument, pageIndex: pageIndex, completion: completion)
			return
		}

		guard viewportWillChange, let document = pdfView.document else {
			lastViewportSize = bounds.size
			return
		}

		applyLayout(
			for: document,
			preserving: preservedViewport,
			zoomPolicy: .relativeToFit
		)
		lastViewportSize = bounds.size
	}

	func setContinuousLayout(_ layout: PDFContinuousLayout) {
		guard continuousLayout != layout else { return }
		let viewport = hasPresentedDocument ? PDFViewportState.capture(from: pdfView) : nil
		continuousLayout = layout
		guard let document = pdfView.document, hasPresentedDocument else { return }
		applyLayout(
			for: document,
			preserving: viewport,
			zoomPolicy: .relativeToFit
		)
	}

	func setDisplayCountChangeHandler(
		_ onChange: @escaping @MainActor (Int) -> Void
	) {
		onDisplayCountChange = onChange
		onChange(reportedDisplayCount)
	}

	func represents(_ document: PDFDocument) -> Bool {
		representedSourceDocument === document
	}

	func installInitial(
		document: PDFDocument,
		pageIndex: Int = 0,
		completion: @escaping () -> Void
	) {
		guard pdfView.document == nil, !hasPresentedDocument else {
			completion()
			return
		}
		representedSourceDocument = document
		pendingInitialDocument = document
		pendingInitialPageIndex = max(pageIndex, 0)
		initialCompletion = completion
		setNeedsLayout()
	}

	func replaceDocument(with document: PDFDocument, completion: @escaping () -> Void) {
		guard !represents(document) else {
			completion()
			return
		}
		guard bounds.width > 0, bounds.height > 0, let displayedDocument = pdfView.document else {
			installInitial(document: document, completion: completion)
			return
		}

		let generation = UUID()
		replacementGeneration = generation
		representedSourceDocument = document
		let viewport = PDFViewportState.capture(from: pdfView)
		let oldPageSize = pageSize(of: displayedDocument)
		let newPageSize = pageSize(of: document)
		let desiredMode = resolvedDisplayMode(for: document)
		let geometryChanged = desiredMode != pdfView.displayMode
			|| !oldPageSize.sbjApproximatelyEquals(newPageSize)
		isPerformingDocumentTransaction = true

		var pagesReplaced = false
		CATransaction.begin()
		CATransaction.setDisableActions(true)
		UIView.performWithoutAnimation {
			configureDisplayMode(desiredMode)
			pagesReplaced = replacePages(in: displayedDocument, from: document)
			pdfView.layoutIfNeeded()
			pdfView.layoutDocumentView()
		}
		CATransaction.commit()
		guard pagesReplaced else {
			isPerformingDocumentTransaction = false
			completion()
			return
		}

		let useCanonicalTopAtFit = viewport?.isAtTopAtFit == true && !geometryChanged
		if !useCanonicalTopAtFit {
			restore(viewport, in: pdfView, zoomPolicy: geometryChanged ? .relativeToFit : .absolute)
		}

		Task { @MainActor [weak self, weak pdfView] in
			guard let self, let pdfView else { return }
			// PDFKit still performs part of page-layout invalidation asynchronously.
			// Let it settle before applying the final viewing state.
			await Task.yield()
			pdfView.layoutIfNeeded()
			pdfView.layoutDocumentView()

			if useCanonicalTopAtFit {
				self.restoreTopAtFit(in: pdfView)
			} else {
				self.restore(viewport, in: pdfView, zoomPolicy: geometryChanged ? .relativeToFit : .absolute)
				await Task.yield()
				guard self.replacementGeneration == generation, self.represents(document) else { return }
				pdfView.layoutIfNeeded()
				pdfView.layoutDocumentView()
				self.restore(viewport, in: pdfView, zoomPolicy: geometryChanged ? .relativeToFit : .absolute)
			}

			guard self.replacementGeneration == generation, self.represents(document) else { return }
			self.isPerformingDocumentTransaction = false
			self.lastViewportSize = self.bounds.size
			completion()
		}
	}

	/// Updates the PDF already attached to `PDFView` without assigning a new
	/// `PDFView.document`. Assigning a new document causes PDFKit's internal
	/// `PDFDocumentView` to become first responder. Keeping the displayed document
	/// identity stable lets editing controls elsewhere in the window retain focus.
	private func replacePages(in displayed: PDFDocument, from source: PDFDocument) -> Bool {
		// Clone the generated PDF first so moving pages into the displayed document
		// cannot mutate the source document retained by the presentation controller.
		guard let data = source.dataRepresentation(),
			let donor = PDFDocument(data: data)
		else { return false }

		let replacementPages = (0..<donor.pageCount).compactMap { donor.page(at: $0) }
		let commonCount = min(displayed.pageCount, replacementPages.count)

		// Insert-before-remove means the attached document is never temporarily empty
		// when the old and new PDFs both have pages.
		if commonCount > 0 {
			for index in 0..<commonCount {
				displayed.insert(replacementPages[index], at: index)
				displayed.removePage(at: index + 1)
			}
		}

		if replacementPages.count > commonCount {
			for index in commonCount..<replacementPages.count {
				displayed.insert(replacementPages[index], at: index)
			}
		} else {
			while displayed.pageCount > replacementPages.count {
				displayed.removePage(at: displayed.pageCount - 1)
			}
		}

		return displayed.pageCount == replacementPages.count
	}


	private func presentInitial(
		document: PDFDocument,
		pageIndex: Int,
		completion: (() -> Void)?
	) {
		let generation = UUID()
		replacementGeneration = generation
		isPerformingDocumentTransaction = true
		pdfView.alpha = 0
		configureDisplayMode(resolvedDisplayMode(for: document))

		// The interactive PDFView owns a private display document from the beginning.
		// Generated source documents remain immutable presentation payloads. Keeping the
		// attached document identity stable also avoids PDFKit stealing first responder
		// on later live edits.
		guard let displayedDocument = cloneDocument(document) else {
			isPerformingDocumentTransaction = false
			completion?()
			return
		}
		pdfView.document = displayedDocument
		pdfView.layoutIfNeeded()
		pdfView.layoutDocumentView()

		restoreInitialPage(pageIndex)

		Task { @MainActor [weak self, weak pdfView] in
			guard let self, let pdfView else { return }
			await Task.yield()
			pdfView.layoutIfNeeded()
			pdfView.layoutDocumentView()
			self.restoreInitialPage(pageIndex)
			await Task.yield()
			guard self.replacementGeneration == generation, self.represents(document) else { return }
			pdfView.layoutIfNeeded()
			pdfView.layoutDocumentView()
			self.restoreInitialPage(pageIndex)
			self.hasPresentedDocument = true
			self.isPerformingDocumentTransaction = false
			self.lastViewportSize = self.bounds.size
			pdfView.alpha = 1
			completion?()
		}
	}

	private func restoreInitialPage(_ pageIndex: Int) {
		if pageIndex == 0 {
			pdfView.sbjClampMinimumScaleToFit()
			alignToTopOfFirstPage()
		} else {
			restoreLogicalPage(pageIndex, in: pdfView)
		}
	}

	private func cloneDocument(_ source: PDFDocument) -> PDFDocument? {
		guard let data = source.dataRepresentation() else { return nil }
		return PDFDocument(data: data)
	}

	private func applyLayout(
		for document: PDFDocument,
		preserving viewport: PDFViewportState?,
		zoomPolicy: ZoomRestorePolicy
	) {
		guard !isPerformingDocumentTransaction else { return }
		let previousMode = pdfView.displayMode
		let desiredMode = resolvedDisplayMode(for: document)
		let modeChanged = previousMode != desiredMode
		let pageToPreserve = currentLogicalPageIndex()

		UIView.performWithoutAnimation {
			configureDisplayMode(desiredMode)
			pdfView.layoutIfNeeded()
			pdfView.layoutDocumentView()
			if modeChanged {
				restoreLogicalPage(pageToPreserve, in: pdfView)
			} else {
				restore(viewport, in: pdfView, zoomPolicy: zoomPolicy)
			}
		}

		Task { @MainActor [weak self, weak pdfView] in
			guard let self, let pdfView else { return }
			await Task.yield()
			UIView.performWithoutAnimation {
				pdfView.layoutIfNeeded()
				pdfView.layoutDocumentView()
				if modeChanged {
					self.restoreLogicalPage(pageToPreserve, in: pdfView)
				} else {
					self.restore(viewport, in: pdfView, zoomPolicy: zoomPolicy)
				}
			}

			if modeChanged {
				await Task.yield()
				pdfView.layoutIfNeeded()
				pdfView.layoutDocumentView()
				self.restoreLogicalPage(pageToPreserve, in: pdfView)
			}
		}
	}


	private func currentLogicalPageIndex() -> Int {
		pdfView.sbjLogicalPageIndex ?? 0
	}

	/// Configures the interaction model as well as the page arrangement.
	/// Single-page documents use a vertically continuous scroll view. Two-page
	/// spreads use PDFKit's UIPageViewController-backed navigation so moving
	/// through the document is horizontal spread-by-spread rather than a grid.
	private func configureDisplayMode(_ mode: PDFDisplayMode) {
		switch mode {
		case .twoUp:
			reportDisplayCount(2)
			pdfView.displayMode = .twoUp
			pdfView.displayDirection = .horizontal
			pdfView.displaysAsBook = false
			if !pdfView.isUsingPageViewController {
				pdfView.usePageViewController(
					true,
					withViewOptions: [UIPageViewController.OptionsKey.interPageSpacing: 12]
				)
			}

		default:
			reportDisplayCount(1)
			if pdfView.isUsingPageViewController {
				pdfView.usePageViewController(false, withViewOptions: nil)
			}
			pdfView.displayMode = .singlePageContinuous
			pdfView.displayDirection = .vertical
			pdfView.displaysAsBook = false
		}
	}

	private func reportDisplayCount(_ count: Int) {
		guard reportedDisplayCount != count else { return }
		reportedDisplayCount = count
		onDisplayCountChange(count)
	}

	private func resolvedDisplayMode(for document: PDFDocument) -> PDFDisplayMode {
		switch continuousLayout {
		case .singlePage:
			return .singlePageContinuous
		case .adaptive(let policy):
			guard let pageSize = pageSize(of: document) else { return .singlePageContinuous }
			return policy.displayMode(
				viewport: bounds.size,
				pageSize: pageSize,
				current: pdfView.displayMode
			)
		}
	}

	private func pageSize(of document: PDFDocument?) -> CGSize? {
		guard let page = document?.page(at: 0) else { return nil }
		return page.bounds(for: pdfView.displayBox).size
	}

	private func alignToTopOfFirstPage() {
		guard let page = pdfView.document?.page(at: 0) else { return }
		let pageBounds = page.bounds(for: pdfView.displayBox)
		pdfView.go(to: PDFDestination(
			page: page,
			at: CGPoint(x: pageBounds.minX, y: pageBounds.maxY)
		))
	}

	/// A single-page ↔ two-up transition changes the meaning of zoom and scroll
	/// geometry. Preserve only the user's logical page, then fit the new layout.
	private func restoreLogicalPage(_ pageIndex: Int, in pdfView: PDFView) {
		pdfView.layoutIfNeeded()
		pdfView.layoutDocumentView()

		let fittedScale = pdfView.scaleFactorForSizeToFit
		if fittedScale.isFinite, fittedScale > 0 {
			if pdfView.maxScaleFactor < fittedScale { pdfView.maxScaleFactor = fittedScale }
			pdfView.minScaleFactor = fittedScale
			pdfView.scaleFactor = fittedScale
		}

		guard let document = pdfView.document, document.pageCount > 0 else { return }
		let resolvedIndex = min(max(pageIndex, 0), document.pageCount - 1)
		guard let page = document.page(at: resolvedIndex) else { return }
		pdfView.go(to: page)
	}

	private enum ZoomRestorePolicy {
		case absolute
		case relativeToFit
	}

	/// Restores the canonical initial viewing state without using PDFKit navigation.
	/// This avoids a visible go-to/scroll cycle when the user is already at the
	/// top of the document at fit scale.
	private func restoreTopAtFit(in pdfView: PDFView) {
		pdfView.sbjClampMinimumScaleToFit()
		pdfView.layoutIfNeeded()
		pdfView.layoutDocumentView()

		if pdfView.isUsingPageViewController {
			if let firstPage = pdfView.document?.page(at: 0) {
				pdfView.go(to: firstPage)
			}
			return
		}

		guard let scrollView = pdfView.sbjScrollView else { return }
		let top = CGPoint(
			x: scrollView.contentOffset.x,
			y: -scrollView.adjustedContentInset.top
		)
		scrollView.setContentOffset(scrollView.sbjClampedContentOffset(top), animated: false)
	}

	private func restore(
		_ state: PDFViewportState?,
		in pdfView: PDFView,
		zoomPolicy: ZoomRestorePolicy = .absolute
	) {
		guard let state, let document = pdfView.document else {
			pdfView.sbjClampMinimumScaleToFit()
			return
		}

		let fittedScale = pdfView.scaleFactorForSizeToFit
		let requestedScale: CGFloat? = switch zoomPolicy {
		case .absolute:
			state.scaleFactor.isFinite && state.scaleFactor > 0 ? state.scaleFactor : nil
		case .relativeToFit:
			if let ratio = state.fitScaleRatio, ratio.isFinite, ratio > 0, fittedScale.isFinite, fittedScale > 0 {
			fittedScale * ratio
			} else {
				nil
			}
		}

		if let requestedScale {
			pdfView.minScaleFactor = fittedScale
			if pdfView.maxScaleFactor < requestedScale { pdfView.maxScaleFactor = requestedScale }
			pdfView.scaleFactor = max(requestedScale, fittedScale)
		} else {
			pdfView.sbjClampMinimumScaleToFit()
		}
		pdfView.layoutIfNeeded()
		pdfView.layoutDocumentView()

		if let anchor = state.anchor,
			anchor.pageIndex >= 0,
			anchor.pageIndex < document.pageCount,
			let page = document.page(at: anchor.pageIndex)
		{
			restore(anchor: anchor, on: page, in: pdfView)
		}
	}

	private func restore(anchor: PDFViewportState.Anchor, on page: PDFPage, in pdfView: PDFView) {
		let pageBounds = page.bounds(for: pdfView.displayBox)
		let pagePoint = CGPoint(
			x: pageBounds.minX + anchor.normalizedPoint.x * pageBounds.width,
			y: pageBounds.minY + anchor.normalizedPoint.y * pageBounds.height
		)

		// First bring the target page near the viewport so PDFKit has laid out the
		// destination page, then adjust the underlying scroll view so the stored page
		// point is centered exactly where it was before replacement.
		pdfView.go(to: PDFDestination(page: page, at: pagePoint))
		pdfView.layoutIfNeeded()
		if pdfView.isUsingPageViewController { return }
		guard let scrollView = pdfView.sbjScrollView else { return }
		let pointInView = pdfView.convert(pagePoint, from: page)
		let viewportCenter = CGPoint(x: pdfView.bounds.midX, y: pdfView.bounds.midY)
		let proposed = CGPoint(
			x: scrollView.contentOffset.x + pointInView.x - viewportCenter.x,
			y: scrollView.contentOffset.y + pointInView.y - viewportCenter.y
		)
		scrollView.setContentOffset(scrollView.sbjClampedContentOffset(proposed), animated: false)
	}

}

@MainActor
final class FitClampedPDFView: PDFView {
	override func layoutSubviews() {
		super.layoutSubviews()
		sbjClampMinimumScaleToFit()
	}
}

extension PDFView {
	/// The first logical page represented by the current viewport. Two-up mode uses
	/// the first visible page so page state describes the displayed spread consistently.
	@MainActor
	var sbjLogicalPageIndex: Int? {
		guard let document, document.pageCount > 0 else { return nil }

		if isUsingPageViewController {
			let visibleIndices = visiblePages.compactMap { page -> Int? in
				let index = document.index(for: page)
				return index == NSNotFound ? nil : index
			}
			if let firstVisible = visibleIndices.min() { return firstVisible }
		}

		guard let currentPage else { return nil }
		let index = document.index(for: currentPage)
		return index == NSNotFound ? nil : index
	}

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

	@MainActor
	func sbjClampMinimumScaleToFit() {
		guard document != nil, bounds.width > 0, bounds.height > 0 else { return }
		let fittedScale = scaleFactorForSizeToFit
		guard fittedScale.isFinite, fittedScale > 0 else { return }
		if maxScaleFactor < fittedScale { maxScaleFactor = fittedScale }
		if minScaleFactor != fittedScale { minScaleFactor = fittedScale }
		if scaleFactor < fittedScale { scaleFactor = fittedScale }
	}

	@MainActor
	var sbjScrollView: UIScrollView? {
		subviews.lazy.compactMap(\.sbjFirstScrollView).first
	}
}

private extension UIView {
	var sbjFirstScrollView: UIScrollView? {
		if let scrollView = self as? UIScrollView { return scrollView }
		return subviews.lazy.compactMap(\.sbjFirstScrollView).first
	}
}

private extension Optional where Wrapped == CGSize {
	func sbjApproximatelyEquals(_ other: CGSize?) -> Bool {
		guard let lhs = self, let rhs = other else { return self == nil && other == nil }
		return abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
	}
}

private extension UIScrollView {
	func sbjClampedContentOffset(_ proposed: CGPoint) -> CGPoint {
		let minX = -adjustedContentInset.left
		let minY = -adjustedContentInset.top
		let maxX = max(minX, contentSize.width - bounds.width + adjustedContentInset.right)
		let maxY = max(minY, contentSize.height - bounds.height + adjustedContentInset.bottom)
		return CGPoint(
			x: min(max(proposed.x, minX), maxX),
			y: min(max(proposed.y, minY), maxY)
		)
	}
}
#endif
