import Foundation
import SBJFoundation

public struct PageContext: Equatable, Sendable {
	/// Zero-based source page index in the complete paginated document.
	public let index: Int
	/// One-based source page number in the complete paginated document.
	public let number: Int
	/// Total source page count after measurement/pagination.
	public let count: Int

	public init(index: Int, number: Int, count: Int) {
		self.index = index
		self.number = number
		self.count = count
	}
}

public struct RenderableContext: @unchecked Sendable {
	public var pagination: Pagination
	public var jargon: Jargon
	private var pageOverride: PageContext?

	/// The physical source page currently being rendered, when rendering has
	/// reached a page. During ordinary measurement this is `nil`.
	public var page: PageContext? {
		pageOverride ?? pagination.currentPageContext
	}

	public init(
		jargon: Jargon = .standard,
		pagination: Pagination = Pagination(),
		page: PageContext? = nil
	) {
		self.pagination = pagination
		self.jargon = jargon
		self.pageOverride = page
	}

	public func with(
		jargon: Jargon? = nil,
		pagination: Pagination? = nil,
		page: PageContext? = nil
	) -> Self {
		var context = self
		if let pagination {
			context.pagination = pagination
		}
		if let jargon {
			context.jargon = jargon
		}
		if let page {
			context.pageOverride = page
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
		page: PageContext? = nil,
		operation: () throws -> Result
	) rethrows -> Result {
		try withContext(
			context.with(jargon: jargon, pagination: pagination, page: page),
			operation: operation
		)
	}
}
