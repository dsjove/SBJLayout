#if !os(watchOS)
import Observation

@MainActor
public protocol PDFPageNavigating: AnyObject, Observable {
	var pageLabel: String { get }
	var pageAccessibilityLabel: String { get }
	var canGoBackward: Bool { get }
	var canGoForward: Bool { get }

	func goToFirstPage()
	func goToPreviousPage()
	func goToNextPage()
	func goToLastPage()
}
#endif
