#if !os(watchOS)
import PDFKit

/// A declarative update to a PDF presentation.
///
/// `content` replaces the presented PDF and its position map when supplied.
/// `selection` requests a one-shot reveal/highlight, either in the current
/// content or, when bundled with new content, after that content is installed.
public struct PDFPresentationUpdate<PositionID: Hashable> {
	public struct Content {
		public let document: PDFDocument?
		public let positions: [PositionID: PaginationPosition]

		public init(
			document: PDFDocument?,
			positions: [PositionID: PaginationPosition]
		) {
			self.document = document
			self.positions = positions
		}
	}

	public let content: Content?
	public let selection: PositionID?

	public init(
		content: Content? = nil,
		selection: PositionID? = nil
	) {
		self.content = content
		self.selection = selection
	}
}
#endif
