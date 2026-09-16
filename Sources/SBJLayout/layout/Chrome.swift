import CoreGraphics
import SBJFoundation

/// A draw-only page/layout element.
///
/// `Chrome` does not participate in measurement. The caller is responsible for
/// determining both the allocated rectangle and the measured size supplied to
/// `render`.
public protocol Chrome {
	// Draw with unbounded allocated or measured values is undefined.
	func render(in allocated: CGRect, measured: CGSize, align: Alignment)
}

public extension Chrome {
	static var context: RenderableContext {
		RenderableEnvironment.context
	}

	static var pagination: Pagination {
		context.pagination
	}

	static var jargon: Jargon {
		context.jargon
	}

	static var page: PageContext? {
		context.page
	}

	// Draws using the allocated size when no explicit measured size is supplied.
	func render(in allocated: CGRect, measured: CGSize? = nil, align: Alignment = .leftTop) {
		render(in: allocated, measured: measured ?? allocated.size, align: align)
	}
}
