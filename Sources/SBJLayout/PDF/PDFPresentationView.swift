#if !os(watchOS)
import PDFKit
import SwiftUI
import SBJFoundation

/// Renders one persistent, adaptively laid-out PDF view and its transient
/// pagination highlight. Page arrangement is selected by StablePDFView from
/// the actual viewport and PDF page geometry.
@MainActor
public struct PDFPresentationView<PositionID: Hashable>: View {
	private let presentation: PDFPresentationController<PositionID>

	public init(presentation: PDFPresentationController<PositionID>) {
		self.presentation = presentation
	}

	public var body: some View {
		ZStack(alignment: .topLeading) {
			if let displayedDocument = presentation.displayedDocument {
				StablePDFView(
					document: displayedDocument,
					controller: presentation.continuousController,
					layout: .adaptive(),
					onReady: { presentation.pdfViewReady() }
				)
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
}
#endif
