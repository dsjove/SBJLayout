#if !os(watchOS)
import Observation
import PDFKit
import SwiftUI

/// Reusable SwiftUI-facing presentation state for generated PDFs.
///
/// The controller owns document replacement/cross-fade state, navigation to generated
/// pagination geometry, transient highlight state, and both continuous and paged navigation
/// controllers. Applications decide *which* presentation mode to use; SBJLayout owns how
/// that mode is hosted.
@Observable
@MainActor
public final class PDFPresentationController<Input: Identifiable, PositionID: Hashable> {
	public let continuousController = PDFViewController()
	public let pagedController: PDFPagedViewController

	public private(set) var displayedDocument: PDFDocument?
	public private(set) var outgoingDocument: PDFDocument?
	public private(set) var displayedOpacity = 1.0
	public private(set) var outgoingOpacity = 0.0
	public private(set) var positions: [PositionID: PaginationPosition] = [:]

	public private(set) var highlightRect: CGRect?
	public private(set) var highlightOpacity = 0.0
	public private(set) var highlightScale = 1.0

	private var displayedInputs: Input?
	private var crossFadeGeneration = UUID()
	private var navigationGeneration = UUID()
	private var highlightTask: Task<Void, Never>?
	private var pendingPositionID: PositionID?
	private var lastNavigatedPositionID: PositionID?
	private var viewportSize: CGSize = .zero
	private var viewportNavigationTask: Task<Void, Never>?
	private let crossFadeDuration: TimeInterval

	public init(pagesPerView: Int = 1, crossFadeDuration: TimeInterval = 0.25) {
		self.pagedController = PDFPagedViewController(pagesPerView: pagesPerView)
		self.crossFadeDuration = crossFadeDuration
	}

	public func update(
		to newDocument: PDFDocument?,
		positions newPositions: [PositionID: PaginationPosition],
		inputs: Input?
	) {
		pagedController.update(document: newDocument)

		guard let newDocument else {
			displayedDocument = nil
			outgoingDocument = nil
			positions = [:]
			displayedInputs = nil
			pendingPositionID = nil
			lastNavigatedPositionID = nil
			viewportNavigationTask?.cancel()
			viewportNavigationTask = nil
			cancelHighlight()
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
		cancelHighlight()

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

	public func go(to positionID: PositionID?) {
		pendingPositionID = positionID
		lastNavigatedPositionID = positionID
		if positionID == nil {
			viewportNavigationTask?.cancel()
			viewportNavigationTask = nil
			cancelHighlight()
		}
		performPendingNavigationIfReady()
	}

	public func viewportDidChange(to size: CGSize) {
		guard size.width > 0, size.height > 0, size != viewportSize else { return }
		viewportSize = size
		guard let positionID = lastNavigatedPositionID else { return }

		viewportNavigationTask?.cancel()
		viewportNavigationTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: .milliseconds(220))
			guard !Task.isCancelled, let self else { return }
			pendingPositionID = positionID
			performPendingNavigationIfReady()
		}
	}

	public func goAfterDocumentUpdate(to positionID: PositionID) {
		pendingPositionID = positionID
		lastNavigatedPositionID = positionID
	}

	public func pdfViewReady() {
		performPendingNavigationIfReady()
	}

	private func performPendingNavigationIfReady() {
		guard let positionID = pendingPositionID,
			displayedDocument != nil,
			let position = positions[positionID]
		else { return }

		cancelHighlight()
		let generation = UUID()
		navigationGeneration = generation
		pendingPositionID = nil

		highlightTask = Task { @MainActor [weak self] in
			guard let self else { return }
			let settlingDelays: [Duration] = [.zero, .milliseconds(80), .milliseconds(180)]
			var finalRect: CGRect?

			for delay in settlingDelays {
				if delay != .zero { try? await Task.sleep(for: delay) }
				guard !Task.isCancelled, navigationGeneration == generation else { return }
				if let rect = await continuousController.go(to: position) {
					finalRect = rect
				}
			}

			guard !Task.isCancelled, navigationGeneration == generation else { return }
			guard let finalRect else {
				pendingPositionID = positionID
				return
			}
			await animateHighlight(finalRect)
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

	private func replaceWithoutAnimation(
		_ document: PDFDocument,
		positions newPositions: [PositionID: PaginationPosition],
		inputs: Input?
	) {
		cancelHighlight()
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
#endif
