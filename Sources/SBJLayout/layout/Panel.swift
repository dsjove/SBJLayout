import CoreGraphics
import UIKit

public struct Panel<C: Renderable>: Renderable {
	let insets: Insets
	//TODO: Feature - Aspect Ratio
	let background: JCSRect?
	let backgroundImage: LayoutImage?
	let backgroundImageAlignment: Alignment
	let content: C?

	public init(
		insets: Insets = .zero,
		background: JCSRect? = nil,
		backgroundImage: LayoutImage? = nil,
		backgroundImageAlignment: Alignment = .center,
		@RenderableOptionalBuilder<C>
		content: ()->C?
	) {
		self.init(
			insets: insets,
			background: background,
			backgroundImage: backgroundImage,
			backgroundImageAlignment: backgroundImageAlignment,
			content: content()
		)
	}

	public init(
		insets: Insets = .zero,
		background: JCSRect? = nil,
		backgroundImage: LayoutImage? = nil,
		backgroundImageAlignment: Alignment = .center,
		content: C?
	) {
		self.content = content
		self.insets = insets
		self.background = background
		self.backgroundImage = backgroundImage
		self.backgroundImageAlignment = backgroundImageAlignment
	}
	
	public func measure(bounds: CGSize) -> CGSize {
		if let content {
			insets.apply(to: bounds) { content.measure(bounds: $0) }
		} else {
			.zero
		}
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		if let content {
			background?.draw(in: allocated)
			if let backgroundImage, let ctx = UIGraphicsGetCurrentContext() {
				ctx.saveGState()
				ctx.clip(to: allocated)
				backgroundImage.render(
					in: allocated,
					measured: allocated.size,
					align: backgroundImageAlignment
				)
				ctx.restoreGState()
			}
			let positioned = insets.apply(to: allocated)
			let contentMeasured = insets.apply(to: measured)
			content.render(in: positioned, measured: contentMeasured, align: align)
		}
	}
}
