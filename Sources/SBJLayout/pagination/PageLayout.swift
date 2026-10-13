import Foundation
import SBJFoundation

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
	public var left: UnitValue<LengthUnit>
	public var right: UnitValue<LengthUnit>
	public var top: UnitValue<LengthUnit>
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
		let defaultMargin = UnitValue<LengthUnit>(
			pageSize.marginUnit == .millimeter ? 6.35 : 0.25,
			unit: pageSize.marginUnit
		)
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

	public static func propertyInfo<Value>(for keyPath: KeyPath<Self, Value>) -> SBJPropertyInfo? {
		switch keyPath as AnyKeyPath {
		case \Self.pageSize:
			SBJPropertyInfo(summary: "Paper size used for PDF layout.", details: "The preferred unit for margins is inches, or millimeters for ISO A paper sizes. Changing paper-size families converts existing measurements without altering physical distances.")
		case \Self.landscape:
			SBJPropertyInfo(summary: "Use landscape page orientation rather than portrait.", details: "")
		case \Self.top:
			SBJPropertyInfo(summary: "Top page margin, including its unit.", details: "")
		case \Self.bottom:
			SBJPropertyInfo(summary: "Bottom page margin, including its unit.", details: "")
		case \Self.left:
			SBJPropertyInfo(summary: "Left page margin, including its unit.", details: "")
		case \Self.right:
			SBJPropertyInfo(summary: "Right page margin, including its unit.", details: "")
		default: nil
		}
	}
}
