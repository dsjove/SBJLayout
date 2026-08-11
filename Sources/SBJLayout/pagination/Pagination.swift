import Foundation
import CoreGraphics

public protocol Pagination: AnyObject {
	var size: PageSize { get }
	var margin: Insets { get }
	var landscape: Bool { get }

	var contentRect: CGRect { get }

	func registerGroup() -> Int
	func measuredGroup(_ id: Int?, _ size: CGSize, pageBreak: Bool, spacingBefore: CGFloat)
	func renderingGroup(_ id: Int?, from origin: CGPoint) -> CGPoint
}

public extension Pagination {
	var pageRect: CGRect { size.rect(landscape: landscape, margin: .zero) }
	var printableRect: CGRect { size.rect(landscape: landscape, margin: margin) }

	func measuredGroup(_ id: Int?, _ size: CGSize, spacingBefore: CGFloat = 0) {
		measuredGroup(id, size, pageBreak: false, spacingBefore: spacingBefore)
	}
}

public class BasicPagination: Pagination {
	public let size: PageSize
	public let margin: Insets
	public let landscape: Bool
	public let paging: ((Pagination) -> ())?

//TODO: Bug - we need a seperate class/struct for the two-pass vars
	public private(set) var contentRect: CGRect = .zero
	public var estimatedPageCountMax: Int? = nil
	public var pageNumber: Int {pages.count}

	private var groupId: Int = 0
	private var hasMeasured: Bool = false
	private var measured: Set<Int> = []
	private var pages: Set<Int> = []
	private var measurePageOffsetY: CGFloat = 0
	private var renderPageOffsetY: CGFloat = 0

	public init(
		size: PageSize = PageSize.letter,
		margin: Insets = .init(dx: 18.0, dy: 18.0),
		insets: Insets = .init(),
		landscape: Bool = false,
		paging: ((Pagination) -> ())? = nil
	) {
		self.size = size
		self.margin = margin
		self.landscape = landscape
		self.paging = paging
		self.measurePageOffsetY = -1
		self.contentRect = insets.apply(to: printableRect)
	}

	public func registerGroup() -> Int {
		let id = groupId
//print("Group\(id) Register")
		groupId += 1
		return id
	}

	public func measuredGroup(_ id: Int?, _ size: CGSize, pageBreak: Bool, spacingBefore: CGFloat) {
		let height = size.height
//print("Group\(id ?? -1) Measured")
		guard height > 0, height.isFinite else {
//print("Group\(id ?? -1): Invalid Height -> \(pages.count)")
			return
		}

		let pageHeight = contentRect.height

		let newPage = {
			self.measurePageOffsetY = height
			if let id {
				self.pages.insert(id)
			}
		}

		if !hasMeasured {
			hasMeasured = true
			newPage()
//print("Page Height: \(pageHeight)")
//print("Group\(id ?? -1): FirstMeasure -> \(pages.count) \(measurePageOffsetY)")
			return
		}

		if pageBreak {
			newPage()
//print("Group\(id ?? -1): Forced Page Break -> \(pages.count) - \(measurePageOffsetY)")
			return
		}

		//TODO: Feature - support splitting
		//TODO: Feature - variable content size for best fit
		if height > pageHeight {
			newPage()
//print("Group\(id ?? -1): Too Tall -> \(pages.count) \(measurePageOffsetY)")
			return
		}

		let spacing = max(0, spacingBefore)
		if measurePageOffsetY + spacing + height > pageHeight {
			newPage()
//print("Group\(id ?? -1): Does Not Fit -> \(pages.count) - \(measurePageOffsetY)")
			return
		}

		measurePageOffsetY += spacing + height
//print("Group\(id ?? -1): Fits -> \(pages.count) \(measurePageOffsetY)")
	}

	public func renderingGroup(_ id: Int?, from origin: CGPoint) -> CGPoint {
		guard let id else { return origin }
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
