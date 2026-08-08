import Foundation
import CoreGraphics

public protocol Pagination: AnyObject {
	var size: PageSize { get }
	var margin: CGSize { get }
	var landscape: Bool { get }

	func registerGroup() -> Int
	func measuredGroup(_ id: Int?, _ size: CGSize, spacingBefore: CGFloat)
	func renderingGroup(_ id: Int?, from origin: CGPoint) -> CGPoint
}

public extension Pagination {
	var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	var printableRect: CGRect { size.rect(landscape: landscape, margin: margin) }
}

public class BasicPagination: Pagination {
	public let size: PageSize
	public let margin: CGSize
	public let landscape: Bool
	public let paging: ((Pagination) -> ())?

	public private(set) var groupId: Int = 0
	public private(set) var pages: Set<Int> = []
	public private(set) var goupY: CGFloat = 0
	public private(set) var hasMeasured: Bool = false
	private var renderPageOffsetY: CGFloat = 0

	public init(
		size: PageSize = PageSize.letter,
		margin: CGSize = CGSize(width: 18.0, height: 18.0),
		landscape: Bool = false,
		paging: ((Pagination) -> ())? = nil
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.paging = paging
		self.goupY = -1
	}

	public func registerGroup() -> Int {
		let id = groupId
		groupId += 1
		return id
	}

	public func measuredGroup(_ id: Int?, _ size: CGSize, spacingBefore: CGFloat = 0) {
		let height = size.height
		guard height > 0, height.isFinite else {
print("Group\(id ?? -1): Invalid Height -> \(pages.count)")
			return
		}

		let pageHeight = printableRect.height

		let newPage = {
			self.goupY = height
			if let id {
				self.pages.insert(id)
			}
		}

		if !hasMeasured {
			hasMeasured = true
			newPage()
print("Page Height: \(pageHeight)")
print("Group\(id ?? -1): FirstMeasure -> \(pages.count) \(goupY)")
			return
		}

		// A group cannot be split. Give an oversized group its own page;
		// leaving goupY > pageHeight ensures the following group starts a new page.
		if height > pageHeight {
			newPage()
print("Group\(id ?? -1): Too Tall -> \(pages.count) \(goupY)")
			return
		}

		let spacing = max(0, spacingBefore)
		if goupY + spacing + height > pageHeight {
			newPage()
print("Group\(id ?? -1): Does Not Fit -> \(pages.count) - \(goupY)")
			return
		}

		goupY += spacing + height
print("Group\(id ?? -1): Fits -> \(pages.count) \(goupY)")
	}

	public func renderingGroup(_ id: Int?, from origin: CGPoint) -> CGPoint {
		guard let id else { return origin }
print("Group\(id) Render")
		if pages.contains(id) {
print("   Paging")
			paging?(self)
			renderPageOffsetY = origin.y - printableRect.origin.y
		}
		return CGPoint(
			x: origin.x,
			y: origin.y - renderPageOffsetY
		)
	}
}
