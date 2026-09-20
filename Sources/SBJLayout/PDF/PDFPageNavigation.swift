#if !os(watchOS)
import Observation

public struct PDFCurrentPage: Equatable, Sendable, CustomStringConvertible {
    public let pageNumber: Int
    public let displayCount: Int
    public let pageCount: Int

    public init(pageNumber: Int, displayCount: Int, pageCount: Int) {
        self.pageNumber = pageNumber
        self.displayCount = displayCount
        self.pageCount = pageCount
    }

    var canGoBackward: Bool {
        pageCount > 0 && pageNumber > 1
    }

    var canGoForward: Bool {
        guard pageCount > 0, pageNumber > 0, displayCount > 0 else {
            return false
        }

        return pageNumber + displayCount - 1 < pageCount
    }

    public var description: String {
        guard pageCount > 0, pageNumber > 0, displayCount > 0 else {
            return ""
        }

        let first = min(max(pageNumber, 1), pageCount)
        let last = min(first + displayCount - 1, pageCount)

        if first == last {
            return "\(first)/\(pageCount)"
        }

        return "\(first)-\(last)/\(pageCount)"
    }


	public var pageAccessibilityLabel: String {
		guard pageCount > 0, pageNumber > 0, displayCount > 0 else {
			return ""
		}

		let first = min(max(pageNumber, 1), pageCount)
		let last = min(first + displayCount - 1, pageCount)

		if first == last {
			return "Page \(first) of \(pageCount)"
		}

		return "Pages \(first) through \(last) of \(pageCount)"
	}

    public static let empty = PDFCurrentPage(
        pageNumber: 0,
        displayCount: 0,
        pageCount: 0
    )
}

@MainActor
public protocol PDFPageNavigating: AnyObject, Observable {
	var currentPage: PDFCurrentPage { get }
	func goToFirstPage()
	func goToPreviousPage()
	func goToNextPage()
	func goToLastPage()
}
#endif
