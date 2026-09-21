import CoreGraphics
import UIKit
import SBJFoundation

/// Core Graphics representation of a semantic tag.
///
/// Tag storage and SwiftUI controls live in SBJFoundation. Printable rendering
/// belongs in SBJLayout so clients do not need their own PDF-only tag geometry.
public struct JCSTag: Renderable {
	public let displayName: String
	public let color: CodableColor
	public let isPrimary: Bool

	private let viewModel: Panel<Panel<JCSText>>
	private let isEmpty: Bool

	public init(displayName: String, color: CodableColor, isPrimary: Bool = false) {
		self.displayName = displayName
		self.color = color
		self.isPrimary = isPrimary
		isEmpty = displayName.isEmpty

		let horizontalPadding: CGFloat = 8
		let verticalPadding: CGFloat = 2
		let cornerRadius: CGFloat = 8
		let reservedStrokeWidth: CGFloat = 2

		let baseFont = UIFont.preferredFont(forTextStyle: .caption1)
		let font: UIFont
		if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
			font = UIFont(descriptor: descriptor, size: baseFont.pointSize)
		} else {
			font = baseFont
		}

		let fillColor = color.uiColor
		let foregroundColor: UIColor = fillColor.isLight ? .black : .white

		let chrome = JCSRect(
			fill: fillColor,
			stroke: isPrimary ? .black : .clear,
			lineWidth: reservedStrokeWidth,
			radius: cornerRadius
		)

		let text = JCSText(
			verbatim: displayName,
			font: font,
			color: foregroundColor,
			align: .center,
			lines: 1...1,
			lineBreakMode: .byTruncatingTail
		)

		viewModel = Panel(insets: Insets(dx: reservedStrokeWidth / 2)) {
			Panel(
				insets: Insets(dx: horizontalPadding, dy: verticalPadding),
				background: chrome
			) {
				text
			}
		}
	}

	public func measure(bounds: CGSize) -> CGSize {
		guard !isEmpty else { return .zero }
		return viewModel.measure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		guard !isEmpty else { return }
		let rect = align.apply(size: measured, in: allocated)
		viewModel.render(in: rect, measured: measured, align: .center)
	}
}

/// A wrapping printable group of semantic tags.
///
/// Tags flow horizontally until the supplied width is exhausted, then continue
/// on the next row. With an unbounded width the group remains a single row.
public struct JCSTagGroup: Renderable {
	public let tags: [JCSTag]
	public let horizontalGap: CGFloat
	public let verticalGap: CGFloat

	public init(
		_ tags: [JCSTag],
		horizontalGap: CGFloat = 10,
		verticalGap: CGFloat = 6
	) {
		self.tags = tags
		self.horizontalGap = horizontalGap
		self.verticalGap = verticalGap
	}

	private var grid: Grid {
		Grid(
			cols: .init(
				.intrinsic(),
				align: .centerX,
				gap: horizontalGap,
				maxCount: tags.count
			),
			rows: .init(
				.intrinsic(),
				align: .centerY,
				gap: verticalGap
			),
			arrangement: .gaps,
			wrapping: .horizontal,
			cells: tags.map { $0 as any Renderable }
		)
	}

	public func measure(bounds: CGSize) -> CGSize {
		guard !tags.isEmpty else { return .zero }
		return grid.measure(bounds: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		guard !tags.isEmpty else { return }
		grid.render(in: allocated, measured: measured, align: align)
	}
}

public extension Tagging {
	func renderable(isPrimary: Bool = false) -> JCSTag {
		JCSTag(displayName: displayName, color: color, isPrimary: isPrimary)
	}
}

public extension TagUser {
	/// Printable tags in the same stable sort order used by the SwiftUI tag UI.
	func renderableTags(
		horizontalGap: CGFloat = 10,
		verticalGap: CGFloat = 6
	) -> JCSTagGroup {
		JCSTagGroup(
			sortedTags.map { tag in
				tag.renderable(isPrimary: isTagPrimary(tag))
			},
			horizontalGap: horizontalGap,
			verticalGap: verticalGap
		)
	}
}
