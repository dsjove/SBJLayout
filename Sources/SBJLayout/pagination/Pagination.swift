import Foundation
import CoreGraphics

public struct PaginationPosition: Equatable, Sendable {
	public let pageIndex: Int
	public let frame: CGRect
	public let pageRect: CGRect

	public init(pageIndex: Int, frame: CGRect, pageRect: CGRect) {
		self.pageIndex = pageIndex
		self.frame = frame
		self.pageRect = pageRect
	}
}

struct PaginationGroupKey: Hashable {
	let order: Int
	let sectionID: String
}

public class Pagination {
	private struct MeasuredGroup {
		let key: PaginationGroupKey
		var size: CGSize
		var behavior: PaginationBehavior
		var spacingBefore: CGFloat
		var terminatesLine: Bool
	}

	private struct PaginationLine {
		var keys: [PaginationGroupKey]
		var width: CGFloat
		var height: CGFloat
		var spacingBefore: CGFloat
		var forcePage: Bool
		var keepWithPrevious: Bool
	}

	private struct PaginationUnit {
		var keys: [PaginationGroupKey]
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
	public private(set) var positions: [String: PaginationPosition] = [:]

	private var nextGroupOrder = 0
	private var groups: [PaginationGroupKey: MeasuredGroup] = [:]
	private var pages: Set<PaginationGroupKey> = []
	private var renderPageOffsetY: CGFloat = 0
	private var renderPageIndex = -1

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

	func registerGroup(sectionID: String) -> PaginationGroupKey {
		defer { nextGroupOrder += 1 }
		return PaginationGroupKey(order: nextGroupOrder, sectionID: sectionID)
	}

	func measuredGroup(_ key: PaginationGroupKey, _ size: CGSize, spacingBefore: CGFloat = 0) {
		measuredGroup(
			key,
			size,
			behavior: .flow,
			spacingBefore: spacingBefore,
			terminatesLine: true
		)
	}

	func measuredGroup(
		_ key: PaginationGroupKey,
		_ size: CGSize,
		behavior: PaginationBehavior,
		spacingBefore: CGFloat,
		terminatesLine: Bool = true
	) {
		guard size.height > 0, size.height.isFinite else {
			groups.removeValue(forKey: key)
			positions.removeValue(forKey: key.sectionID)
			recalculatePages()
			return
		}

		groups[key] = MeasuredGroup(
			key: key,
			size: size,
			behavior: behavior,
			spacingBefore: max(0, spacingBefore),
			terminatesLine: terminatesLine
		)
		recalculatePages()
	}

	private func recalculatePages() {
		pages.removeAll(keepingCapacity: true)
		let measured = groups.values.sorted { $0.key.order < $1.key.order }
		guard !measured.isEmpty else { return }

		let lines = paginationLines(from: measured)
		var units: [PaginationUnit] = []
		for line in lines {
			if line.keepWithPrevious, !line.forcePage, !units.isEmpty {
				let index = units.index(before: units.endIndex)
				units[index].keys.append(contentsOf: line.keys)
				units[index].height += line.spacingBefore + line.height
			} else {
				units.append(PaginationUnit(
					keys: line.keys,
					height: line.height,
					spacingBefore: line.spacingBefore,
					forcePage: line.forcePage
				))
			}
		}

		let pageHeight = contentRect.height
		var pageOffsetY: CGFloat = 0

		for (index, unit) in units.enumerated() {
			let firstKey = unit.keys[0]
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
				pages.insert(firstKey)
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
			guard let line = current, !line.keys.isEmpty else { return }
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
					keys: [],
					width: 0,
					height: 0,
					spacingBefore: group.spacingBefore,
					forcePage: group.behavior == .page,
					keepWithPrevious: group.behavior == .keepWith
				)
			}

			let gap = current!.keys.isEmpty ? 0 : group.spacingBefore
			current!.keys.append(group.key)
			current!.width += gap + group.size.width
			current!.height = max(current!.height, group.size.height)

			if group.terminatesLine {
				finishLine()
			}
		}

		finishLine()
		return lines
	}

	func renderingGroup(_ key: PaginationGroupKey, frame: CGRect) -> CGPoint {
		if pages.contains(key) {
			paging?(self)
			renderPageIndex += 1
			renderPageOffsetY = frame.origin.y - contentRect.origin.y
		}

		let pageOrigin = CGPoint(
			x: frame.origin.x + (contentRect.origin.x - printableRect.origin.x),
			y: frame.origin.y - renderPageOffsetY
		)
		positions[key.sectionID] = PaginationPosition(
			pageIndex: max(0, renderPageIndex),
			frame: CGRect(origin: pageOrigin, size: frame.size),
			pageRect: pageRect
		)
		return pageOrigin
	}
}
