import SwiftUI
import SBJFoundation

/// SwiftUI page-navigation chrome for a ``StablePDFView``.
///
/// The view deliberately knows nothing about PDFKit's `PDFView`; all viewer
/// mechanics are contained by ``PDFViewController``.
public struct PageManagementView: View {
	@Bindable var controller: PDFViewController

	public init(controller: PDFViewController) {
		self.controller = controller
	}

	public var body: some View {
		HStack(spacing: 8) {
			Button(action: controller.goToFirstPage) {
				Image(.system("backward.end"))
			}
			.accessibilityLabel("First Page")
			.disabled(!controller.canGoToPreviousPage)

			Button(action: controller.goToPreviousPage) {
				Image(.system("chevron.left"))
			}
			.accessibilityLabel("Previous Page")
			.disabled(!controller.canGoToPreviousPage)

			Text("\(controller.currentPageNumber)/\(controller.pageCount)")
				.monospacedDigit()
				.fixedSize()
				.accessibilityLabel("Page \(controller.currentPageNumber) of \(controller.pageCount)")

			Button(action: controller.goToNextPage) {
				Image(.system("chevron.right"))
			}
			.accessibilityLabel("Next Page")
			.disabled(!controller.canGoToNextPage)

			Button(action: controller.goToLastPage) {
				Image(.system("forward.end"))
			}
			.accessibilityLabel("Last Page")
			.disabled(!controller.canGoToNextPage)
		}
	}
}
