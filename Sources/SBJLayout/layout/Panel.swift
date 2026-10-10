import CoreGraphics
import Foundation

public struct Panel<C: Renderable>: Renderable, PaginationTraversable {
    private let decorationID: UUID

    var hasPaginationGroups: Bool {
        (content as? any PaginationTraversable)?.hasPaginationGroups == true
    }

    func collectPaginationEvents(
        in allocated: CGRect, measured: CGSize, align: Alignment,
        into events: inout [PaginationEvent]
    ) {
        guard let traversable = content as? any PaginationTraversable,
              traversable.hasPaginationGroups else { return }
        if let background {
            events.append(.beginDecoration(decorationID, background, allocated))
        }
        traversable.collectPaginationEvents(
            in: insets.apply(to: allocated),
            measured: insets.apply(to: measured),
            align: align,
            into: &events
        )
        if background != nil { events.append(.endDecoration(decorationID)) }
    }

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
        self.decorationID = UUID()
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
