import Foundation
import SBJFoundation
import SBJLocalization

@SBJStructure
public struct PageLayout: Codable, Equatable, Sendable {
	public var pageSize: PageSize {
		didSet {
			let unit = pageSize.marginUnit
			guard oldValue.marginUnit != unit else { return }
			top = top.converted(to: unit)
			bottom = bottom.converted(to: unit)
			left = left.converted(to: unit)
			right = right.converted(to: unit)
		}
	}
	public var landscape: Bool
	@SBJUnitValue(immutableUnit: true)
	public var left: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var right: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var top: UnitValue<LengthUnit>
	@SBJUnitValue(immutableUnit: true)
	public var bottom: UnitValue<LengthUnit>

	public init(
		pageSize: PageSize = .letter,
		landscape: Bool = false,
		left: UnitValue<LengthUnit>? = nil,
		right: UnitValue<LengthUnit>? = nil,
		top: UnitValue<LengthUnit>? = nil,
		bottom: UnitValue<LengthUnit>? = nil
	) {
		self.pageSize = pageSize
		self.landscape = landscape
		let defaultMargin = pageSize.defaultMargin
		self.top = top ?? defaultMargin
		self.bottom = bottom ?? defaultMargin
		self.left = left ?? defaultMargin
		self.right = right ?? defaultMargin
	}

	public var pageRect: CGRect {
		pageSize.rect(landscape: landscape, margin: .zero)
	}

	public var printableRect: CGRect {
		pageSize.rect(landscape: landscape, margin: marginsInPDFPoints)
	}

	/// PDF rendering geometry; all unit conversion stays on PageLayout.
	public var marginsInPDFPoints: Insets {
		Insets(
			left: CGFloat(left.converted(to: .point).value),
			right: CGFloat(right.converted(to: .point).value),
			top: CGFloat(top.converted(to: .point).value),
			bottom: CGFloat(bottom.converted(to: .point).value)
		)
	}

    // Statically discovered by @SBJStructure; no key-path switch required.
    public static let pageSizeInfo = SBJPropertyInfo(
        summary: "Paper size used for PDF layout.",
        details: "The preferred unit for margins is inches, or millimeters for ISO A paper sizes. Changing paper-size families converts existing measurements without altering physical distances."
    )
    public static let landscapeInfo = SBJPropertyInfo(summary: "Use landscape page orientation rather than portrait.")
    public static let topInfo = SBJPropertyInfo(summary: "Top page margin, including its unit.")
    public static let bottomInfo = SBJPropertyInfo(summary: "Bottom page margin, including its unit.")
    public static let leftInfo = SBJPropertyInfo(summary: "Left page margin, including its unit.")
    public static let rightInfo = SBJPropertyInfo(summary: "Right page margin, including its unit.")
}
