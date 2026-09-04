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

	public init(pageLayout: Binding<PageLayout>) {
		_pageLayout = pageLayout
	}

	public var body: some View {
		Form {
			Section("Page") {
				Menu {
					pageSizeMenuSection("North American", sizes: PageSize.northAmerican)
					pageSizeMenuSection("ISO A", sizes: PageSize.isoA)
					pageSizeMenuSection("Photo", sizes: PageSize.photo)
				} label: {
					LabeledContent("Page Size") {
						SBJCompactMenuLabel(text: pageLayout.pageSize.description)
					}
				}
				Toggle("Landscape", isOn: $pageLayout.landscape)
			}

			Section("Margins") {
				marginRow("Top", keyPath: \.top)
				marginRow("Bottom", keyPath: \.bottom)
				marginRow("Left", keyPath: \.left)
				marginRow("Right", keyPath: \.right)
			}
		}
	}

	@ViewBuilder
	private func pageSizeMenuSection(_ title: String, sizes: [PageSize]) -> some View {
		Section(title) {
			ForEach(sizes, id: \.self) { size in
				Button {
					pageLayout.pageSize = size
				} label: {
					if pageLayout.pageSize == size {
						Label(size.description, image: .system("checkmark"))
					} else {
						Text(size.description)
					}
				}
			}
		}
	}

	private var marginUnit: LengthUnit {
		switch pageLayout.pageSize.category {
		case .isoA:
			.millimeter
		case .northAmerican, .photo, .special, .custom:
			.inch
		}
	}

	private func marginRow(_ title: String, keyPath: KeyPath<Insets, CGFloat>) -> some View {
		HStack {
			Text(title)
			Spacer()
			UnitValueControl(
				value: marginBinding(keyPath),
				units: [marginUnit],
				accessibilityLabel: title
			)
		}
	}

	private func marginBinding(_ keyPath: KeyPath<Insets, CGFloat>) -> Binding<UnitValue<LengthUnit>> {
		Binding(
			get: {
				UnitValue<LengthUnit>(
					Double(pageLayout.margins[keyPath: keyPath]),
					unit: .point
				)
				.converted(to: marginUnit)
			},
			set: { displayedValue in
				let points = displayedValue
					.converted(to: .point)
					.value
				let value = CGFloat(max(0, points))
				pageLayout.margins = Insets(
					left: keyPath == \.left ? value : pageLayout.margins.left,
					right: keyPath == \.right ? value : pageLayout.margins.right,
					top: keyPath == \.top ? value : pageLayout.margins.top,
					bottom: keyPath == \.bottom ? value : pageLayout.margins.bottom
				)
			}
		)
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
				.navigationBarTitleDisplayMode(.inline)
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
