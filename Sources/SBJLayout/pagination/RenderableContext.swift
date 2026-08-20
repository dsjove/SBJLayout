public struct RenderableContext: @unchecked Sendable {
	public var pagination: Pagination
	public var jargon: Jargon

	public init(
		jargon: Jargon = .standard,
		pagination: Pagination = Pagination()
	) {
		self.pagination = pagination
		self.jargon = jargon
	}

	public func with(
		jargon: Jargon? = nil,
		pagination: Pagination? = nil
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
	public static func withContext<Result>(
		jargon: Jargon = .standard,
		pagination: Pagination = Pagination(),
		operation: () throws -> Result
	) rethrows -> Result {
		try withContext(context.with(jargon: jargon, pagination: pagination), operation: operation)
	}
}
