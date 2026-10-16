#if !os(watchOS) && !os(tvOS)
import SwiftUI
import Foundation
import SBJFoundation

/// The reusable page-layout editor body.
///
/// This view deliberately owns no navigation or presentation chrome, so an
/// application can place it inside its normal sheet/window editor host without
/// introducing a second `NavigationStack`, title, Restore button, or Done
/// button.
public struct PageLayoutEditorCore: View {
	@Binding private var pageLayout: PageLayout
    @State private var presentationModel = SBJEditorPresentationModel(
		formattingOptions: .init(trailingAlignedFields: true)
	)

	public init(pageLayout: Binding<PageLayout>) {
		_pageLayout = pageLayout
	}

	public var body: some View {
        SBJEditorScrollView(presentationModel: presentationModel) {
            SBJEditorView(value: $pageLayout, presentationModel: presentationModel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
    }
}

/// Compatibility presentation wrapper around ``PageLayoutEditorCore``.
///
/// Existing callers can keep presenting this view directly. Callers that
/// already provide editor navigation/chrome should use `PageLayoutEditorCore`
/// with a binding instead.
public struct PageLayoutEditorView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var pageLayout: PageLayout
	@State private var originalPageLayout: PageLayout
	private let onChange: (PageLayout) -> Void

	public init(pageLayout: PageLayout, onChange: @escaping (PageLayout) -> Void) {
		_pageLayout = State(initialValue: pageLayout)
		_originalPageLayout = State(initialValue: pageLayout)
		self.onChange = onChange
	}

	public var body: some View {
		NavigationStack {
			PageLayoutEditorCore(pageLayout: $pageLayout)
				.navigationTitle("Page Layout")
				.sbjInlineNavigationTitle()
				.toolbar {
					ToolbarItem(placement: .cancellationAction) {
						Button("Restore") {
							pageLayout = originalPageLayout
						}
						.disabled(pageLayout == originalPageLayout)
					}
					ToolbarItem(placement: .confirmationAction) {
						Button("Done") { dismiss() }
					}
				}
				.onChange(of: pageLayout) { _, newValue in
					onChange(newValue)
				}
		}
	}
}
#endif
