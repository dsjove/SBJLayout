import CoreGraphics

public protocol JCSLayoutElement: TrackElement {
	// allocated and contentSize with unbounded values is undefined
	func draw(in allocated: CGRect, measured: CGSize, align: Alignment)

	var pagination: Pagination { get }
}

public extension JCSLayoutElement {
	// Does not measure, uses alloacted size if no measurement supplied
	func draw(in allocated: CGRect, measured: CGSize? = nil, align: Alignment = .leftTop) {
		draw(in: allocated, measured: measured ?? allocated.size, align: align)
	}

	// Auto measures, draws at origin, and returns allocated rect at origin
	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded, align: Alignment = .leftTop) -> CGRect {
		let measured = measure(bounds: bounds)
		let allocated = CGRect(origin: origin, size: measured)
		draw(in: allocated, measured: measured, align: align)
		return allocated
	}

	var pagination: Pagination {
		layoutElementPage
	}
}

public struct JCSEmptyDrawable: JCSLayoutElement {
	public let size: CGSize

	public init (size: CGSize = .zero) {
		self.size = size
	}

	public func measure(bounds: CGSize) -> CGSize {
		CGSize(
			width: size.width.isUnbounded ? size.width : bounds.width,
			height: size.height.isUnbounded ? size.height : bounds.height)
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {}
}

public typealias JCSLayoutElements = [any JCSLayoutElement]

@resultBuilder
public struct JCSLayoutElementBuilder {
	public typealias Component = JCSLayoutElements

	public static func buildExpression<T: JCSLayoutElement>(
		_ expression: T
	) -> Component {
		[expression]
	}

	public static func buildExpression(
		_ expression: Component
	) -> Component {
		expression
	}

	public static func buildExpression<T: JCSLayoutElement>(
		_ expression: [T]
	) -> Component {
		expression.map { $0 as any JCSLayoutElement }
	}
	public static func buildBlock(
		_ components: Component...
	) -> Component {
		components.flatMap { $0 }
	}

	public static func buildExpression<T: JCSLayoutElement>(
		_ expression: [[T]]
	) -> Component {
		expression.flatMap { $0 }.map { $0 as any JCSLayoutElement }
	}

	public static func buildOptional(
		_ component: Component?
	) -> Component {
		component ?? []
	}

	public static func buildEither(
		first component: Component
	) -> Component {
		component
	}

	public static func buildEither(
		second component: Component
	) -> Component {
		component
	}

	public static func buildArray(
		_ components: [Component]
	) -> Component {
		components.flatMap { $0 }
	}
}

@resultBuilder
public struct JCSLayoutElementOptionalBuilder<Element: JCSLayoutElement> {
    public typealias Component = Element?

    public static func buildExpression(
        _ expression: Element
    ) -> Component {
        expression
    }

    public static func buildOptional(
        _ component: Component?
    ) -> Component {
        component ?? nil
    }

    public static func buildEither(
        first component: Component
    ) -> Component {
        component
    }

    public static func buildEither(
        second component: Component
    ) -> Component {
        component
    }

    public static func buildBlock(
        _ component: Component
    ) -> Component {
        component
    }

    public static func buildBlock() -> Component {
        nil
    }
}
