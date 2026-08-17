import Foundation
import CoreGraphics

public class Pagination {
	private struct MeasuredGroup {
		let id: Int
		var size: CGSize
		var behavior: PaginationBehavior
		var spacingBefore: CGFloat
	}

	private struct PaginationUnit {
		var ids: [Int]
		var height: CGFloat
		var spacingBefore: CGFloat
		var forcePage: Bool
	}

	public let size: PageSize
	public let margin: Insets
	public let landscape: Bool
	public let estimatedPageCountMax: Int?
	public let paging: ((Pagination) -> ())?

	public var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	public var printableRect: CGRect { size.rect(landscape: landscape, margin: margin) }
	public let contentRect: CGRect

	public var pageNumber: Int { pages.count }

	private var groupId: Int = 0
	private var groups: [Int: MeasuredGroup] = [:]
	private var pages: Set<Int> = []
	private var renderPageOffsetY: CGFloat = 0

	public init(
		size: PageSize = PageSize.unbounded,
		margin: Insets = .zero,
		insets: Insets = .zero,
		landscape: Bool = false,
		estimatedPageCountMax: Int? = nil,
		paging: ((Pagination) -> ())? = nil
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.estimatedPageCountMax = estimatedPageCountMax
		self.paging = paging
		let printableRect: CGRect = size.rect(landscape: landscape, margin: margin)
		self.contentRect = insets.apply(to: printableRect)
	}

	public func registerGroup() -> Int {
		let id = groupId
		groupId += 1
		return id
	}

	func measuredGroup(_ id: Int, _ size: CGSize, spacingBefore: CGFloat = 0) {
		measuredGroup(id, size, behavior: .flow, spacingBefore: spacingBefore)
	}

	public func measuredGroup(
		_ id: Int,
		_ size: CGSize,
		behavior: PaginationBehavior,
		spacingBefore: CGFloat
	) {
		guard size.height > 0, size.height.isFinite else {
			groups.removeValue(forKey: id)
			recalculatePages()
			return
		}

		groups[id] = MeasuredGroup(
			id: id,
			size: size,
			behavior: behavior,
			spacingBefore: max(0, spacingBefore)
		)
		recalculatePages()
	}

	private func recalculatePages() {
		pages.removeAll(keepingCapacity: true)
		let measured = groups.values.sorted { $0.id < $1.id }
		guard !measured.isEmpty else { return }

		var units: [PaginationUnit] = []
		for group in measured {
			if group.behavior == .keepWith, !units.isEmpty {
				units[units.index(before: units.endIndex)].ids.append(group.id)
				units[units.index(before: units.endIndex)].height += group.spacingBefore + group.size.height
			} else {
				units.append(PaginationUnit(
					ids: [group.id],
					height: group.size.height,
					spacingBefore: group.spacingBefore,
					forcePage: group.behavior == .page
				))
			}
		}

		let pageHeight = contentRect.height
		var pageOffsetY: CGFloat = 0

		for (index, unit) in units.enumerated() {
			let firstId = unit.ids[0]
			let startsPage: Bool
			if index == 0 {
				startsPage = true
			} else if unit.forcePage {
				startsPage = true
			} else if unit.height > pageHeight {
				startsPage = true
			} else {
				startsPage = pageOffsetY + unit.spacingBefore + unit.height > pageHeight
			}

			if startsPage {
				pages.insert(firstId)
				pageOffsetY = unit.height
			} else {
				pageOffsetY += unit.spacingBefore + unit.height
			}
		}
	}

	public func renderingGroup(_ id: Int, from origin: CGPoint) -> CGPoint {
		if pages.contains(id) {
			paging?(self)
			renderPageOffsetY = origin.y - contentRect.origin.y
		}
		return CGPoint(
			x: contentRect.origin.x,
			y: origin.y - renderPageOffsetY
		)
	}
}
