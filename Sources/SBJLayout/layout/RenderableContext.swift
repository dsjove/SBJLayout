public struct RenderableContext: @unchecked Sendable {
	public var pagination: Pagination
	public var jargon: Jargon

	public init(
		pagination: Pagination = BasicPagination(),
		jargon: Jargon = .standard
	) {
		self.pagination = pagination
		self.jargon = jargon
	}

	public func with(
		pagination: Pagination? = nil,
		jargon: Jargon? = nil
	) -> Self {
		var context = self
		if let pagination {
			context.pagination = pagination
		}
		if let jargon {
			context.jargon = jargon
		}
		return context
	}
}

public enum RenderableEnvironment {
	@TaskLocal public static var context: RenderableContext = .init()

	@discardableResult
	public static func withContext<Result>(
		_ context: RenderableContext,
		operation: () throws -> Result
	) rethrows -> Result {
		try $context.withValue(context, operation: operation)
	}

	@discardableResult
	public static func withPagination<Result>(
		_ pagination: Pagination,
		operation: () throws -> Result
	) rethrows -> Result {
		try withContext(context.with(pagination: pagination), operation: operation)
	}

	@discardableResult
	public static func withJargon<Result>(
		_ jargon: Jargon,
		operation: () throws -> Result
	) rethrows -> Result {
		try withContext(context.with(jargon: jargon), operation: operation)
	}
}
