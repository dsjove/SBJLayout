import Observation
import PDFKit
import SwiftUI

/// Owns PDFKit view identity, section navigation, and the visual transition between rendered documents.
/// The sheet view only decides *when* a new render is available; this object decides how that render
/// replaces the currently displayed PDF.
@Observable
@MainActor
final class PDFPresentation<Input: Identifiable> {
	var pdfView: PDFView?
	private(set) var displayedDocument: PDFDocument?
	private(set) var outgoingDocument: PDFDocument?
	private(set) var displayedOpacity = 1.0
	private(set) var outgoingOpacity = 0.0
	private(set) var positions: [String: PaginationPosition] = [:]

	private var displayedInputs: Input?
	private var crossFadeGeneration = UUID()
	private var navigationGeneration = UUID()
	private var highlightTask: Task<Void, Never>?
	private weak var sectionHighlightView: UIView?
	private var pendingSectionID: String?
	private let crossFadeDuration = 0.25

	func update(
		to newDocument: PDFDocument?,
		positions newPositions: [String: PaginationPosition],
		inputs: Input?
	) {
		guard let newDocument else {
			displayedDocument = nil
			outgoingDocument = nil
			positions = [:]
			displayedInputs = nil
			pdfView = nil
			pendingSectionID = nil
			cancelSectionHighlight()
			return
		}
		let shouldAnimate = displayedInputs != nil && displayedInputs?.id != inputs?.id

		guard let currentDocument = displayedDocument else {
			replaceWithoutAnimation(newDocument, positions: newPositions, inputs: inputs)
			return
		}
		guard currentDocument !== newDocument else {
			positions = newPositions
			return
		}
		guard shouldAnimate else {
			replaceWithoutAnimation(newDocument, positions: newPositions, inputs: inputs)
			return
		}

		let generation = UUID()
		crossFadeGeneration = generation
		outgoingDocument = currentDocument
		outgoingOpacity = 1
		displayedDocument = newDocument
		positions = newPositions
		displayedOpacity = 0
		displayedInputs = inputs

		withAnimation(.easeInOut(duration: crossFadeDuration)) {
			outgoingOpacity = 0
			displayedOpacity = 1
		}

		Task { @MainActor [weak self] in
			guard let self else { return }
			try? await Task.sleep(for: .seconds(crossFadeDuration))
			guard crossFadeGeneration == generation else { return }
			outgoingDocument = nil
			outgoingOpacity = 0
		}
	}

	func go(to sectionID: String?) {
		pendingSectionID = sectionID
		if sectionID == nil {
			cancelSectionHighlight()
		}
		performPendingNavigationIfReady()
	}

	func pdfViewReady(_ view: PDFView) {
		pdfView = view
		performPendingNavigationIfReady()
	}

	private func performPendingNavigationIfReady() {
		guard let sectionID = pendingSectionID,
			let displayedDocument,
			let pdfView,
			pdfView.document === displayedDocument,
			let position = positions[sectionID]
		else { return }

		cancelSectionHighlight()
		let generation = UUID()
		navigationGeneration = generation

		pdfView.go(to: position)
		pendingSectionID = nil

		highlightTask = Task { @MainActor [weak self, weak pdfView] in
			guard let self, let pdfView else { return }
			await waitForNavigationToSettle(to: position, in: pdfView)
			guard !Task.isCancelled,
				navigationGeneration == generation,
				pdfView.document === displayedDocument
			else { return }
			highlight(position, in: pdfView)
		}
	}

	private func waitForNavigationToSettle(to position: PaginationPosition, in pdfView: PDFView) async {
		var previousRect: CGRect?
		var stableSamples = 0

		// PDFKit does not expose a destination-navigation completion callback.
		// Wait until the section's converted view rect stops moving for a few frames.
		for _ in 0..<30 {
			guard !Task.isCancelled else { return }
			pdfView.layoutIfNeeded()
			guard let rect = viewRect(for: position, in: pdfView) else { return }

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

	private func highlight(_ position: PaginationPosition, in pdfView: PDFView) {
		guard let rect = viewRect(for: position, in: pdfView) else { return }

		let visibleRect = rect.intersection(pdfView.bounds).insetBy(dx: -2, dy: -2)
		guard !visibleRect.isNull, visibleRect.width > 1, visibleRect.height > 1 else { return }

		let highlight = UIView(frame: visibleRect)
		highlight.isUserInteractionEnabled = false
		highlight.backgroundColor = pdfView.tintColor.withAlphaComponent(0.25)
		highlight.layer.borderColor = pdfView.tintColor.withAlphaComponent(0.75).cgColor
		highlight.layer.borderWidth = 4
		highlight.layer.cornerRadius = 6
		highlight.alpha = 0
		highlight.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
		pdfView.addSubview(highlight)
		sectionHighlightView = highlight

		UIView.animate(
			withDuration: 0.18,
			delay: 0,
			options: [.curveEaseOut, .beginFromCurrentState]
		) {
			highlight.alpha = 1
			highlight.transform = .identity
		} completion: { finished in
			guard finished else { return }
			UIView.animate(
				withDuration: 0.55,
				delay: 0.35,
				options: [.curveEaseIn, .beginFromCurrentState]
			) {
				highlight.alpha = 0
			} completion: { _ in
				highlight.removeFromSuperview()
			}
		}
	}

	private func viewRect(for position: PaginationPosition, in pdfView: PDFView) -> CGRect? {
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

	private func cancelSectionHighlight() {
		highlightTask?.cancel()
		highlightTask = nil
		navigationGeneration = UUID()
		sectionHighlightView?.layer.removeAllAnimations()
		sectionHighlightView?.removeFromSuperview()
		sectionHighlightView = nil
	}

	private func replaceWithoutAnimation(
		_ document: PDFDocument,
		positions newPositions: [String: PaginationPosition],
		inputs: Input?
	) {
		var transaction = Transaction(animation: nil)
		transaction.disablesAnimations = true
		withTransaction(transaction) {
			displayedDocument = document
			positions = newPositions
			displayedOpacity = 1
			outgoingDocument = nil
			outgoingOpacity = 0
			displayedInputs = inputs
		}
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
