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
		HStack(spacing: 8) {
			Button(action: controller.goToFirstPage) {
				Image(.system("backward.end"))
			}
			.accessibilityLabel("First Page")
			.disabled(!controller.canGoBackward)

			Button(action: controller.goToPreviousPage) {
				Image(.system("chevron.left"))
			}
			.accessibilityLabel("Previous Page")
			.disabled(!controller.canGoBackward)

			Text(controller.pageLabel)
				.monospacedDigit()
				.fixedSize()
				.accessibilityLabel(controller.pageAccessibilityLabel)

			Button(action: controller.goToNextPage) {
				Image(.system("chevron.right"))
			}
			.accessibilityLabel("Next Page")
			.disabled(!controller.canGoForward)

			Button(action: controller.goToLastPage) {
				Image(.system("forward.end"))
			}
			.accessibilityLabel("Last Page")
			.disabled(!controller.canGoForward)
		}
	}
}
#endif
