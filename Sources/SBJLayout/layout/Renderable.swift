import CoreGraphics

// TODO(Localization/Text fitting): measurement needs a presentation/size-class input
// so a renderable can retry with alternate text candidates (full, compact,
// abbreviated, multiline, etc.) without mutating the model or JCSText. The same
// candidate-selection model should be shared with SBJFoundation/SwiftUI; Layout
// remains responsible for Core Graphics measurement and retry decisions.
public protocol Renderable: TrackElement {
	// init should do any data transformations

	// TrackElement measures

	// Draw, allocated and contentSize with unbounded values is undefined
	func render(in allocated: CGRect, measured: CGSize, align: Alignment)
}

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

	static var context: RenderableContext {
		RenderableEnvironment.context
	}

	static var pagination: Pagination {
		Self.context.pagination
	}

	static var jargon: Jargon {
		context.jargon
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
public typealias RenderableBuilder = TypedFlattenedBuilder<any Renderable>

@resultBuilder
public struct TypedFlattenedBuilder<Element> {
	public typealias Component = [Element]

	public static func buildExpression(
		_ expression: Element
	) -> Component {
		[expression]
	}

	public static func buildExpression(
		_ expression: Component
	) -> Component {
		expression
	}

	public static func buildExpression<T: Sequence>(
		_ expression: T
	) -> Component where T.Element == Element {
		Array(expression)
	}

	public static func buildExpression<T: Sequence>(
		_ expression: T
	) -> Component where T.Element: Sequence, T.Element.Element == Element {
		expression.flatMap { $0 }
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

public typealias RenderableOptionalBuilder<C> = TypedOptionalBuilder<C> where C: Renderable

@resultBuilder
public struct TypedOptionalBuilder<Element> {
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
