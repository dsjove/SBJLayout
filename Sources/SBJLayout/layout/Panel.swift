import CoreGraphics
import Foundation

public struct Panel<C: Renderable>: Renderable {
	let decorationID: UUID
	let insets: Insets
//TODO: API - Replace with a Rect Transformer (maybe PhotoEditGeometry)
	let aspectRatio: AspectRatio?
	let background: JCSRect?
	let content: C?

	public init(
		insets: Insets = .zero,
		aspectRatio: AspectRatio? = nil,
		background: JCSRect? = nil,
		@RenderableOptionalBuilder<C>
		content: ()->C?
	) {
		self.init(insets: insets, aspectRatio: aspectRatio, background: background, content: content())
	}

	public init(
		insets: Insets = .zero,
		aspectRatio: AspectRatio? = nil,
		background: JCSRect? = nil,
		content: C?
	) {
		self.decorationID = UUID()
		self.content = content
		self.insets = insets
		self.aspectRatio = aspectRatio
		self.background = background
	}
	
	public func measure(bounds: CGSize) -> CGSize {
		if let content {
			if let aspectRatio {
				insets.apply(to: bounds) { aspectRatio.filling(content.measure(bounds: $0)) }
			} else {
				insets.apply(to: bounds) { content.measure(bounds: $0) }
			}
		} else {
			.zero
		}
	}

	public func minimumMeasure(bounds: CGSize) -> CGSize {
		if let content {
			insets.apply(to: bounds) { content.minimumMeasure(bounds: $0) }
		} else {
			.zero
		}
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		if let content {
            if !hasPaginationGroups ||
               !RenderableEnvironment.context.pagination.isPrepared ||
               RenderableEnvironment.context.pagination.paging == nil {
                background?.draw(in: allocated)
            }
			let positioned = insets.apply(to: allocated)
			let contentMeasured = insets.apply(to: measured)
			content.render(in: positioned, measured: contentMeasured, align: align)
		}
	}
}
