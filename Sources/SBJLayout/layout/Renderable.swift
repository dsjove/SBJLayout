import CoreGraphics
import SBJFoundation

// TODO(Localization/Text fitting): minimumMeasure now handles geometric
// minimum-content sizing, but candidate fitting still needs a presentation/
// size-class input so a renderable can retry alternate text candidates (full,
// compact, abbreviated, multiline, etc.) without mutating the model or JCSText.
// The same candidate-selection model should be shared with SBJFoundation/SwiftUI;
// Layout remains responsible for Core Graphics measurement and retry decisions.
public protocol Renderable: TrackElement, Chrome {
	// init should do any data transformations

	// TrackElement measures

	// Draw, allocated and contentSize with unbounded values is undefined
	func render(in allocated: CGRect, measured: CGSize, align: Alignment)
}

public extension Renderable {
	func measure() -> CGSize {
		measure(bounds: .unbounded)
	}

	// Auto measures, draws at origin, and returns allocated rect at origin
	@discardableResult
	func draw(at origin: CGPoint, bounds: CGSize = .unbounded, align: Alignment = .leftTop) -> CGRect {
		let measured = measure(bounds: bounds)
		let allocated = CGRect(origin: origin, size: measured)
		render(in: allocated, measured: measured, align: align)
		return allocated
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

	public func minimumMeasure(bounds: CGSize) -> CGSize {
		measure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {}
}

/// An ordered tree of content and pagination scopes. Directives are not layout cells.
/// The builder result retains directive hierarchy while behaving as a
/// collection of its real layout cells for existing nonpagination consumers.
public struct Renderables: RandomAccessCollection {
    public enum Node {
        case content(any Renderable)
        case group(PaginationGroup)
    }

    public let nodes: [Node]
    public let content: [any Renderable]
    public init(_ nodes: [Node] = []) {
        self.nodes = nodes
        self.content = nodes.flatMap { node -> [any Renderable] in
            switch node {
            case .content(let item): [item]
            case .group(let group): group.content.content
            }
        }
    }

    public typealias Index = Int
    public typealias Element = any Renderable
    public var startIndex: Int { content.startIndex }
    public var endIndex: Int { content.endIndex }
    public subscript(position: Int) -> any Renderable { content[position] }
}

@resultBuilder
public enum RenderableBuilder {
    public static func buildExpression(_ expression: any Renderable) -> Renderables {
        Renderables([.content(expression)])
    }
    public static func buildExpression(_ expression: PaginationGroup) -> Renderables {
        Renderables([.group(expression)])
    }
    public static func buildExpression(_ expression: Renderables) -> Renderables { expression }
    public static func buildExpression(_ expression: [any Renderable]) -> Renderables {
        Renderables(expression.map { .content($0) })
    }
    public static func buildExpression<T: Sequence>(_ expression: T) -> Renderables where T.Element: Renderable {
        Renderables(expression.map { .content($0) })
    }
    public static func buildExpression(_ expression: [PaginationGroup]) -> Renderables {
        Renderables(expression.map { .group($0) })
    }
    public static func buildExpression(_ expression: [Renderables]) -> Renderables {
        Renderables(expression.flatMap(\.nodes))
    }
    // Table builders commonly emit rows as arrays of renderables.
    // Flatten the rows in input order without manufacturing Grid cells.
    public static func buildExpression<T: Sequence>(_ expression: T) -> Renderables
        where T.Element: Sequence, T.Element.Element: Renderable {
        Renderables(expression.flatMap { row in row.map { Renderables.Node.content($0) } })
    }
    public static func buildBlock(_ parts: Renderables...) -> Renderables {
        Renderables(parts.flatMap(\.nodes))
    }
    public static func buildOptional(_ part: Renderables?) -> Renderables { part ?? .init() }
    public static func buildEither(first part: Renderables) -> Renderables { part }
    public static func buildEither(second part: Renderables) -> Renderables { part }
    public static func buildArray(_ parts: [Renderables]) -> Renderables {
        Renderables(parts.flatMap(\.nodes))
    }
}

public extension Array {
    @RenderableBuilder
    func renderables(@RenderableBuilder _ content: (Element) -> Renderables) -> Renderables {
        for element in self { content(element) }
    }
}

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
