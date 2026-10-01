#if !os(watchOS)
import Observation
import PDFKit
import SwiftUI

/// Reusable SwiftUI-facing presentation state for generated PDFs.
///
/// The controller owns document replacement, one-shot section reveal requests,
/// transient highlight state, and navigation through one persistent PDF view.
@Observable
@MainActor
public final class PDFPresentationController<PositionID: Hashable> {
	public let continuousController = PDFViewController()

	/// Device-neutral PDF viewing behavior. Applications may change this as their
	/// surrounding layout changes without replacing the presentation controller.
	public var layout: PDFPresentationLayout

	public private(set) var displayedDocument: PDFDocument?
	public private(set) var positions: [PositionID: PaginationPosition] = [:]

	public private(set) var highlightRect: CGRect?
	public private(set) var highlightOpacity = 0.0
	public private(set) var highlightScale = 1.0

	private var navigationGeneration = UUID()
	private var highlightTask: Task<Void, Never>?
	private var pendingPositionID: PositionID?
	private var isPDFViewReadyForDisplayedDocument = false
	private var viewportSize: CGSize = .zero

	public init(layout: PDFPresentationLayout = .adaptive()) {
		self.layout = layout
	}

	/// Applies a declarative presentation update. New content and a selection may
	/// be delivered together so the controller can perform the selection only
	/// after StablePDFView has installed that exact content.
	public func update(_ update: PDFPresentationUpdate<PositionID>) {
		if let content = update.content {
			apply(content: content, selection: update.selection)
		} else if let selection = update.selection {
			pendingPositionID = selection
			performPendingRevealIfReady()
		}
	}

	/// Convenience for a selection-only presentation update.
	public func reveal(_ positionID: PositionID) {
		update(PDFPresentationUpdate(selection: positionID))
	}

	private func apply(
		content: PDFPresentationUpdate<PositionID>.Content,
		selection: PositionID?
	) {
		guard let newDocument = content.document else {
			displayedDocument = nil
			positions = [:]
			pendingPositionID = nil
			isPDFViewReadyForDisplayedDocument = false
			continuousController.resetPageState()
			cancelHighlight()
			return
		}

		let newPositions = content.positions
		let requestedSelection = selection.flatMap { newPositions[$0] == nil ? nil : $0 }

		guard displayedDocument !== newDocument else {
			positions = newPositions
			pendingPositionID = requestedSelection
			performPendingRevealIfReady()
			return
		}

		// StablePDFView owns visual document replacement. Keeping a single
		// SwiftUI/PDFKit host lets it preserve zoom and viewport. A selection bundled
		// with this content waits until StablePDFView reports the replacement ready.
		cancelHighlight()
		displayedDocument = newDocument
		positions = newPositions
		pendingPositionID = requestedSelection
		isPDFViewReadyForDisplayedDocument = false
	}

	/// Layout changes invalidate only the transient highlight rectangle. They do not
	/// retain or replay a previously consumed section reveal.
	public func viewportDidChange(to size: CGSize) {
		guard size.width > 0, size.height > 0, size != viewportSize else { return }
		viewportSize = size
		if highlightRect != nil {
			cancelHighlight()
		}
	}

	public func pdfViewReady() {
		isPDFViewReadyForDisplayedDocument = true
		performPendingRevealIfReady()
	}

	private func performPendingRevealIfReady() {
		guard isPDFViewReadyForDisplayedDocument,
			let positionID = pendingPositionID,
			displayedDocument != nil,
			let position = positions[positionID]
		else { return }

		// Consume before performing. Reveal is an event, never persistent selection.
		pendingPositionID = nil
		cancelHighlight()
		let generation = UUID()
		navigationGeneration = generation

		highlightTask = Task { @MainActor [weak self] in
			guard let self else { return }
			guard let rect = await continuousController.reveal(position) else {
				// Retain only a request that could not yet run because the PDF view
				// itself is not ready.
				guard !Task.isCancelled, navigationGeneration == generation else { return }
				pendingPositionID = positionID
				return
			}
			guard !Task.isCancelled, navigationGeneration == generation else { return }
			await animateHighlight(rect)
		}
	}

	private func animateHighlight(_ rect: CGRect) async {
		highlightRect = rect
		highlightOpacity = 0
		highlightScale = 0.985

		withAnimation(.easeOut(duration: 0.18)) {
			highlightOpacity = 1
			highlightScale = 1
		}
		try? await Task.sleep(for: .milliseconds(530))
		guard !Task.isCancelled else { return }
		withAnimation(.easeIn(duration: 0.55)) { highlightOpacity = 0 }
		try? await Task.sleep(for: .milliseconds(550))
		guard !Task.isCancelled else { return }
		highlightRect = nil
		highlightScale = 1
	}

	private func cancelHighlight() {
		highlightTask?.cancel()
		highlightTask = nil
		navigationGeneration = UUID()

		var transaction = Transaction(animation: nil)
		transaction.disablesAnimations = true
		withTransaction(transaction) {
			highlightRect = nil
			highlightOpacity = 0
			highlightScale = 1
		}
	}
}
#endif
