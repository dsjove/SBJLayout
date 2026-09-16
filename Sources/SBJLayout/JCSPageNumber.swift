import UIKit

/// Renders the current PDF page number while reserving enough width for the
/// expected number of digits in the document's page count.
public struct JCSPageNumber: Renderable {
	public let font: UIFont
	public let estimatedPageCountDigits: Int

	public init(font: UIFont, estimatedPageCountDigits: Int = 3) {
		self.font = font
		self.estimatedPageCountDigits = max(1, estimatedPageCountDigits)
	}

	public func measure(bounds: CGSize) -> CGSize {
		text(pageNumberText: String(repeating: "8", count: estimatedPageCountDigits))
			.measure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: SBJLayout.Alignment) {
		text(pageNumberText: String(Self.page?.number ?? 1))
			.render(in: allocated, measured: measured, align: align)
	}

	private func text(pageNumberText: String) -> JCSText {
		JCSText(verbatim: "Page: \(pageNumberText)", font: font, align: .right)
	}
}
