import Foundation
import CoreGraphics

public protocol Pagination: AnyObject {
	var size: PageSize { get }
	var margin: CGSize { get }
	var landscape: Bool { get }

	func registerGroup() -> Int
	func beginMeasureGroup(_ id: Int?)
	func requestPageInsert(_ id: Int?)
	func endMeasureGroup(_ id: Int?, _ size: CGSize)

	func rendering(_ id: Int?)
	func renderPageInsert(_ id: Int?)
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

	private var groupId: Int = 0

	public private(set) var journal: [Journal] = []
	public private(set) var pages: Set<Int> = []

	public struct Journal: CustomStringConvertible {
		enum State {
			case register
			case beginMeasure
			case pageRequested
			case measured(CGSize)
			case render
			case pageBreak
		}
		var id: Int
		var state: State

		public var description: String {
			let prefix = "\(id): "
			let state = switch state {
			case .register: "registered"
			case .beginMeasure: "measuring"
			case .pageRequested: "paged"
			case .measured(let size): "measured \(size.unboundedDescription)"
			case .render: "rendering"
			case .pageBreak: "page-break"
			}
			return "\(prefix)\(state)"
		}
	}

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
	}

	public func registerGroup() -> Int {
		let id = groupId
		journal.append(Journal(id: id, state: .register))
		groupId += 1
		return id
	}

	public func beginMeasureGroup(_ id: Int?) {
		if let id {
			journal.append(Journal(id: id, state: .beginMeasure))
		}
	}

	public func requestPageInsert(_ id: Int?) {
		if let id {
			journal.append(Journal(id: id, state: .pageRequested))
			pages.insert(id)
		}
	}

	public func endMeasureGroup(_ id: Int?, _ size: CGSize) {
		if let id {
			journal.append(Journal(id: id, state: .measured(size)))
		}
	}

	public func rendering(_ id: Int?) {
		if let id {
			journal.append(Journal(id: id, state: .render))
			if pages.contains(id) {
				renderPageInsert(id)
			}
		}
	}

	public func renderPageInsert(_ id: Int?) {
		journal.append(Journal(id: id ?? -1, state: .pageBreak))
		paging?(self)
	}
}
