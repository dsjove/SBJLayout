import Foundation
import CoreGraphics

public class Pagination {
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
	private var hasMeasured: Bool = false
	private var measured: Set<Int> = []
	private var pages: Set<Int> = []
	private var measurePageOffsetY: CGFloat = 0
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
		self.measurePageOffsetY = -1
		let printableRect: CGRect = size.rect(landscape: landscape, margin: margin)
		self.contentRect = insets.apply(to: printableRect)
	}

	public func registerGroup() -> Int {
		let id = groupId
//print("Group\(id) Register")
		groupId += 1
		return id
	}

	func measuredGroup(_ id: Int, _ size: CGSize, spacingBefore: CGFloat = 0) {
		measuredGroup(id, size, pageBreak: false, spacingBefore: spacingBefore)
	}

	public func measuredGroup(_ id: Int, _ size: CGSize, pageBreak: Bool, spacingBefore: CGFloat) {
		let height = size.height
//print("Group\(id ?? -1) Measured")
		guard height > 0, height.isFinite else {
//print("Group\(id ?? -1): Invalid Height -> \(pages.count)")
			return
		}

		let pageHeight = contentRect.height

		let newPage = {
			self.measurePageOffsetY = height
			self.pages.insert(id)
		}

		if !hasMeasured {
			hasMeasured = true
			newPage()
//print("Page Height: \(pageHeight)")
//print("Group\(id): FirstMeasure -> \(pages.count) \(measurePageOffsetY)")
			return
		}

		if pageBreak {
			newPage()
//print("Group\(id): Forced Page Break -> \(pages.count) - \(measurePageOffsetY)")
			return
		}

		//TODO: Feature - support splitting
		//TODO: Feature - variable content size for best fit
		if height > pageHeight {
			newPage()
//print("Group\(id): Too Tall -> \(pages.count) \(measurePageOffsetY)")
			return
		}

		let spacing = max(0, spacingBefore)
		if measurePageOffsetY + spacing + height > pageHeight {
			newPage()
//print("Group\(id): Does Not Fit -> \(pages.count) - \(measurePageOffsetY)")
			return
		}

		measurePageOffsetY += spacing + height
//print("Group\(id): Fits -> \(pages.count) \(measurePageOffsetY)")
	}

	public func renderingGroup(_ id: Int, from origin: CGPoint) -> CGPoint {
//print("Group\(id) Render")
		if pages.contains(id) {
//print("   Paging")
			paging?(self)
			renderPageOffsetY = origin.y - contentRect.origin.y
		}
		return CGPoint(
			x: contentRect.origin.x,
			y: origin.y - renderPageOffsetY
		)
	}
}
