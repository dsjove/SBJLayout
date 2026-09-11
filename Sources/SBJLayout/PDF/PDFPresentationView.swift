#if !os(watchOS)
import PDFKit
import SwiftUI
import SBJFoundation

/// Generic SBJLayout PDF presentation styles. Applications choose the style from their
/// own idiom/size policy; SBJLayout owns the reusable viewer mechanics.
public enum PDFPresentationStyle: Equatable, Sendable {
	case continuous
	case paged(pagesPerView: Int)
}

/// Renders the document, transition, navigation host, and transient pagination highlight
/// owned by a ``PDFPresentationController``.
@MainActor
public struct PDFPresentationView<Input: Identifiable, PositionID: Hashable>: View {
	private let presentation: PDFPresentationController<Input, PositionID>
	private let style: PDFPresentationStyle

	public init(
		presentation: PDFPresentationController<Input, PositionID>,
		style: PDFPresentationStyle
	) {
		self.presentation = presentation
		self.style = style
	}

	public var body: some View {
		switch style {
		case .continuous:
			continuousContent
		case .paged(let pagesPerView):
			pagedContent(pagesPerView: max(1, pagesPerView))
		}
	}

	private var continuousContent: some View {
		ZStack(alignment: .topLeading) {
			if let outgoingDocument = presentation.outgoingDocument {
				StablePDFView(document: outgoingDocument)
					.opacity(presentation.outgoingOpacity)
					.allowsHitTesting(false)
			}
			if let displayedDocument = presentation.displayedDocument {
				StablePDFView(
					document: displayedDocument,
					controller: presentation.continuousController,
					onReady: { presentation.pdfViewReady() }
				)
				.opacity(presentation.displayedOpacity)
			}
			if let rect = presentation.highlightRect {
				Color.clear
					.frame(width: rect.width, height: rect.height)
					.sbjSelectionHighlight(
						true,
						emphasis: .transient,
						cornerRadius: SBJUIAppearance.transientSelectionCornerRadius
					)
					.offset(x: rect.minX, y: rect.minY)
					.scaleEffect(presentation.highlightScale)
					.opacity(presentation.highlightOpacity)
					.allowsHitTesting(false)
			}
		}
		.background {
			GeometryReader { proxy in
				Color.clear
					.onAppear { presentation.viewportDidChange(to: proxy.size) }
					.onChange(of: proxy.size) { _, size in
						presentation.viewportDidChange(to: size)
					}
			}
		}
	}

	@ViewBuilder
	private func pagedContent(pagesPerView: Int) -> some View {
		if let displayedDocument = presentation.displayedDocument {
			PDFPagedView(
				document: displayedDocument,
				controller: presentation.pagedController,
				pagesPerView: pagesPerView
			)
			.opacity(presentation.displayedOpacity)
		}
	}
}
#endif
