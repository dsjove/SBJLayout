import CoreGraphics

//TODO: Feature - add size class to measure/draw for retries
public protocol Renderable: TrackElement {
	// allocated and contentSize with unbounded values is undefined
	func render(in allocated: CGRect, measured: CGSize, align: Alignment)

	var pagination: Pagination { get }
}

//TODO: Bug -should this be an !optional only active during rendering and thread safe?
nonisolated(unsafe) internal var layoutElementPage: Pagination = BasicPagination()

public extension Renderable {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	// Does not measure, uses allocated size if no measurement supplied
	func render(in allocated: CGRect, measured: CGSize? = nil, align: Alignment = .leftTop) {
		render(in: allocated, measured: measured ?? allocated.size, align: align)
	}

	// Auto measures, draws at origin, and returns allocated rect at origin
	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded, align: Alignment = .leftTop) -> CGRect {
		let measured = measure(bounds: bounds)
		let allocated = CGRect(origin: origin, size: measured)
		render(in: allocated, measured: measured, align: align)
		return allocated
	}

	var pagination: Pagination {
		layoutElementPage
	}
}

public struct EmptyRenderable: Renderable {
	public let size: CGSize

	public init(size: CGSize = .zero) {
		self.size = size
	}

	public func measure(bounds: CGSize) -> CGSize {
		CGSize(
			width: size.width.isUnbounded ? size.width : bounds.width,
			height: size.height.isUnbounded ? size.height : bounds.height)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {}
}

public typealias Renderables = [any Renderable]

@resultBuilder
public struct RenderableBuilder {
	public typealias Component = Renderables

	public static func buildExpression<T: Renderable>(
		_ expression: T
	) -> Component {
		[expression]
	}

	public static func buildExpression(
		_ expression: Component
	) -> Component {
		expression
	}

	public static func buildExpression<T: Renderable>(
		_ expression: [T]
	) -> Component {
		expression.map { $0 as any Renderable }
	}

	public static func buildExpression<T: Renderable>(
		_ expression: [[T]]
	) -> Component {
		expression.flatMap { $0 }.map { $0 as any Renderable }
	}

	public static func buildBlock(
		_ components: Component...
	) -> Component {
		components.flatMap { $0 }
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
public struct RenderableOptionalBuilder<Element: Renderable> {
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
