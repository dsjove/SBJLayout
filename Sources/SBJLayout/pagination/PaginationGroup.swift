import Foundation
import CoreGraphics

public enum PaginationBehavior: String, Codable, CaseIterable, Sendable {
	case page
	case keepWith
	case flow
	
	public var displayName: String {
		switch self {
		case .page: "Page Break"
		case .keepWith: "Keep With Above"
		case .flow: "Flow"
		}
	}
}

public struct PaginationGroup: Renderable  {
	var paginationId: Int
	let behavior: PaginationBehavior
	let groupGap: CGFloat
	let grid: Grid

	public init(
		behavior: PaginationBehavior = .flow,
		groupGap: CGFloat,
		@RenderableBuilder
		content: () -> Renderables,
	) {
		self.paginationId = Self.pagination.registerGroup()
		self.behavior = behavior
		self.groupGap = groupGap
		self.grid = Grid(
			vertFlow: .init(.fill()),
			rows: .init(gap: groupGap)
		) {
			content()
		}
	}

	public func measure(bounds: CGSize) -> CGSize {
		let size = self.grid.measure(bounds: bounds)
		Self.pagination.measuredGroup(
			paginationId,
			size,
			behavior: behavior,
			spacingBefore: groupGap
		)
		return size
	}

	public func render(in allocated: CGRect, measured: CGSize, align: SBJLayout.Alignment) {
		let pageOrigin = Self.pagination.renderingGroup(paginationId, from: allocated.origin)
		self.grid.render(in: allocated.reorigin(at: pageOrigin), measured: measured, align: align)
	}
}
