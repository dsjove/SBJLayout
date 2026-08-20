import Foundation

public struct PageLayout: Codable, Equatable, Sendable {
	public var pageSize: PageSize
	public var landscape: Bool
	public var margins: Insets

	public var pageRect: CGRect {
		pageSize.rect(landscape: landscape, margin: .zero)
	}

	public var printableRect: CGRect {
		pageSize.rect(landscape: landscape, margin: margins)
	}

	public init(
		pageSize: PageSize = .letter,
		landscape: Bool = false,
		margins: Insets = .init(dx: 18.0, dy: 18.0)
	) {
		self.pageSize = pageSize
		self.landscape = landscape
		self.margins = margins
	}
}
