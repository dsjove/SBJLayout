import Foundation
import CoreGraphics

public struct PaginationGroup: Renderable  {
	let pageBreak: Bool
	let groupGap: CGFloat
	let grid: Grid
	var paginationId: Int?

	public init(
		pageBreak: Bool,
		groupGap: CGFloat,
		content: () -> Renderables,
	) {
		self.pageBreak = pageBreak
		self.groupGap = groupGap
		self.grid = Grid(
			vertFlow: .init(.fill()),
			rows: .init(gap: groupGap)
		) {
			content()
		}
		self.paginationId = pagination.registerGroup()
	}

	public func measure(bounds: CGSize) -> CGSize {
		let size = self.grid.measure(bounds: bounds)
		pagination.measuredGroup(paginationId, size, pageBreak: pageBreak, spacingBefore: groupGap)
		return size
	}

	public func render(in allocated: CGRect, measured: CGSize, align: SBJLayout.Alignment) {
		let pageOrigin = pagination.renderingGroup(paginationId, from: allocated.origin)
		self.grid.render(in: allocated.reorigin(at: pageOrigin), measured: measured, align: align)
	}
}
