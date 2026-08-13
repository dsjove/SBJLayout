import CoreGraphics

public struct Panel<C: Renderable>: Renderable {
	let insets: Insets
	//TODO: Feature - Aspect Ratio
	let background: JCSRect?
	let content: C?

	public init(
		insets: Insets = .zero,
		background: JCSRect? = nil,
		@RenderableOptionalBuilder<C>
		content: ()->C?
	) {
		self.init(insets: insets, background: background, content: content())
	}

	public init(
		insets: Insets = .zero,
		background: JCSRect? = nil,
		content: C?
	) {
		self.content = content
		self.insets = insets
		self.background = background
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
			let positioned = insets.apply(to: allocated)
			let contentMeasured = insets.apply(to: measured)
			content.render(in: positioned, measured: contentMeasured, align: align)
		}
	}
}
