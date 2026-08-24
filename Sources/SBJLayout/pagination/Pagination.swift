import Foundation
import CoreGraphics

public class Pagination {
	private struct MeasuredGroup {
		let id: Int
		var size: CGSize
		var behavior: PaginationBehavior
		var spacingBefore: CGFloat
		var terminatesLine: Bool
	}

	private struct PaginationLine {
		var ids: [Int]
		var width: CGFloat
		var height: CGFloat
		var spacingBefore: CGFloat
		var forcePage: Bool
		var keepWithPrevious: Bool
	}

	private struct PaginationUnit {
		var ids: [Int]
		var height: CGFloat
		var spacingBefore: CGFloat
		var forcePage: Bool
	}

	public let layout: PageLayout
	public let estimatedPageCountMax: Int?
	public let paging: ((Pagination) -> ())?

	public var pageRect: CGRect { layout.pageRect }
	public var printableRect: CGRect { layout.printableRect }
	public let contentRect: CGRect

	public var pageNumber: Int { pages.count }

	private var groupId: Int = 0
	private var groups: [Int: MeasuredGroup] = [:]
	private var pages: Set<Int> = []
	private var renderPageOffsetY: CGFloat = 0

	public init(
		layout: PageLayout = .init(),
		insets: Insets = .zero,
		estimatedPageCountMax: Int? = nil,
		paging: ((Pagination) -> ())? = nil
	) {
		self.layout = layout
		self.estimatedPageCountMax = estimatedPageCountMax
		self.paging = paging
		self.contentRect = insets.apply(to: layout.printableRect)
	}

	public func registerGroup() -> Int {
		let id = groupId
		groupId += 1
		return id
	}

	func measuredGroup(_ id: Int, _ size: CGSize, spacingBefore: CGFloat = 0) {
		measuredGroup(
			id,
			size,
			behavior: .flow,
			spacingBefore: spacingBefore,
			terminatesLine: true
		)
	}

	public func measuredGroup(
		_ id: Int,
		_ size: CGSize,
		behavior: PaginationBehavior,
		spacingBefore: CGFloat,
		terminatesLine: Bool = true
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
			spacingBefore: max(0, spacingBefore),
			terminatesLine: terminatesLine
		)
		recalculatePages()
	}

	private func recalculatePages() {
		pages.removeAll(keepingCapacity: true)
		let measured = groups.values.sorted { $0.id < $1.id }
		guard !measured.isEmpty else { return }

		let lines = paginationLines(from: measured)
		var units: [PaginationUnit] = []
		for line in lines {
			if line.keepWithPrevious, !line.forcePage, !units.isEmpty {
				let index = units.index(before: units.endIndex)
				units[index].ids.append(contentsOf: line.ids)
				units[index].height += line.spacingBefore + line.height
			} else {
				units.append(PaginationUnit(
					ids: line.ids,
					height: line.height,
					spacingBefore: line.spacingBefore,
					forcePage: line.forcePage
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

	private func paginationLines(from groups: [MeasuredGroup]) -> [PaginationLine] {
		let availableWidth = contentRect.width
		var lines: [PaginationLine] = []
		var current: PaginationLine?

		func finishLine() {
			guard let line = current, !line.ids.isEmpty else { return }
			lines.append(line)
			current = nil
		}

		for group in groups {
			if group.behavior == .page {
				finishLine()
			}

			if let line = current {
				let gap = group.spacingBefore
				if line.width + gap + group.size.width > availableWidth {
					finishLine()
				}
			}

			if current == nil {
				current = PaginationLine(
					ids: [],
					width: 0,
					height: 0,
					spacingBefore: group.spacingBefore,
					forcePage: group.behavior == .page,
					keepWithPrevious: group.behavior == .keepWith
				)
			}

			let gap = current!.ids.isEmpty ? 0 : group.spacingBefore
			current!.ids.append(group.id)
			current!.width += gap + group.size.width
			current!.height = max(current!.height, group.size.height)

			if group.terminatesLine {
				finishLine()
			}
		}

		finishLine()
		return lines
	}

	public func renderingGroup(_ id: Int, from origin: CGPoint) -> CGPoint {
		if pages.contains(id) {
			paging?(self)
			renderPageOffsetY = origin.y - contentRect.origin.y
		}
		return CGPoint(
			x: origin.x + (contentRect.origin.x - printableRect.origin.x),
			y: origin.y - renderPageOffsetY
		)
	}
}
