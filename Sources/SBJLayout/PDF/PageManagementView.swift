#if !os(watchOS)
import SwiftUI
import SBJFoundation

/// Shared SwiftUI page-navigation chrome for any SBJLayout PDF navigation controller.
/// The same builder is used for continuous documents and grouped page presentations.
public struct PageManagementView<Controller: PDFPageNavigating>: View {
	@Bindable var controller: Controller

	public init(controller: Controller) {
		self.controller = controller
	}

	public var body: some View {
		let pageRange = controller.currentPage
		HStack(spacing: 8) {
			Button(action: controller.goToFirstPage) {
				Image(.system("backward.end"))
			}
			.accessibilityLabel("First Page")
			.disabled(!pageRange.canGoBackward)

			Button(action: controller.goToPreviousPage) {
				Image(.system("chevron.left"))
			}
			.accessibilityLabel("Previous Page")
			.disabled(!pageRange.canGoBackward)

			Text(pageRange.description)
				.monospacedDigit()
				.fixedSize()
				.accessibilityLabel(pageRange.pageAccessibilityLabel)

			Button(action: controller.goToNextPage) {
				Image(.system("chevron.right"))
			}
			.accessibilityLabel("Next Page")
			.disabled(!pageRange.canGoForward)

			Button(action: controller.goToLastPage) {
				Image(.system("forward.end"))
			}
			.accessibilityLabel("Last Page")
			.disabled(!pageRange.canGoForward)
		}
	}
}
#endif
