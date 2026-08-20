import SwiftUI
import Foundation

public struct PageLayoutEditorView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var pageLayout: PageLayout
	private let originalPageLayout: PageLayout
	private let onChange: (PageLayout) -> Void

	public init(pageLayout: PageLayout, onChange: @escaping (PageLayout) -> Void) {
		_pageLayout = State(initialValue: pageLayout)
		originalPageLayout = pageLayout
		self.onChange = onChange
	}

	public var body: some View {
		NavigationStack {
			Form {
				Section("Page") {
					Menu {
						pageSizeMenuSection("North American", sizes: PageSize.northAmerican)
						pageSizeMenuSection("ISO A", sizes: PageSize.isoA)
						pageSizeMenuSection("Photo", sizes: PageSize.photo)
					} label: {
						LabeledContent("Page Size") {
							Text(pageLayout.pageSize.description)
								.foregroundStyle(.secondary)
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

	@ViewBuilder
	private func pageSizeMenuSection(_ title: String, sizes: [PageSize]) -> some View {
		Section(title) {
			ForEach(sizes, id: \.self) { size in
				Button {
					pageLayout.pageSize = size
				} label: {
					if pageLayout.pageSize == size {
						Label(size.description, systemImage: "checkmark")
					} else {
						Text(size.description)
					}
				}
			}
		}
	}

	private enum MarginDisplayUnit {
		case inches
		case millimeters

		var unitLength: UnitLength {
			switch self {
			case .inches: .inches
			case .millimeters: .millimeters
			}
		}

		var symbol: String { unitLength.symbol }
	}

	private var marginUnit: MarginDisplayUnit {
		switch pageLayout.pageSize.category {
		case .isoA:
			.millimeters
		case .northAmerican, .photo, .special, .custom:
			.inches
		}
	}

	private func marginRow(_ title: String, keyPath: KeyPath<Insets, CGFloat>) -> some View {
		HStack {
			Text(title)
			Spacer()
			TextField(
				title,
				value: marginBinding(keyPath),
				format: .number.precision(.fractionLength(0...2))
			)
			.textFieldStyle(.roundedBorder)
			.multilineTextAlignment(.trailing)
			.keyboardType(.decimalPad)
			.frame(width: 90)
			Text(marginUnit.symbol)
				.foregroundStyle(.secondary)
				.frame(width: 30, alignment: .leading)
		}
	}

	private func marginBinding(_ keyPath: KeyPath<Insets, CGFloat>) -> Binding<Double> {
		Binding(
			get: {
				Measurement(
					value: Double(pageLayout.margins[keyPath: keyPath]),
					unit: UnitLength.pdfPoints
				)
				.converted(to: marginUnit.unitLength)
				.value
			},
			set: { displayedValue in
				let points = Measurement(
					value: max(0, displayedValue),
					unit: marginUnit.unitLength
				)
				.converted(to: .pdfPoints)
				.value
				let value = CGFloat(points)
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

private extension UnitLength {
	/// PDF/Core Graphics points: 72 points per inch. UnitLength's base unit is meters.
	static let pdfPoints = UnitLength(
		symbol: "pt",
		converter: UnitConverterLinear(coefficient: 0.0254 / 72.0)
	)
}
