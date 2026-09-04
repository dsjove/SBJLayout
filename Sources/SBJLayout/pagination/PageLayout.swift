import Foundation
import SBJFoundation

@SBJStructure
public struct PageLayout: Codable, Equatable, Sendable {
	public var pageSize: PageSize
	public var landscape: Bool
	public var margins: Insets

	public var pageRect: CGRect {
		pageSize.rect(landscape: landscape, margin: .zero)
	}

	public var printableRect: CGRect {
		pageSize.rect(landscape: landscape, margin: margins)
	}

	/// Physical page width represented in the layout engine's native PDF-point unit.
	/// Call `converted(to:)` to present it in inches, millimeters, or another
	/// shared SBJFoundation length unit without leaking conversion math here.
	public var pageWidth: UnitValue<LengthUnit> {
		.init(Double(pageRect.width), unit: .point)
	}

	/// Physical page height represented in the layout engine's native PDF-point unit.
	public var pageHeight: UnitValue<LengthUnit> {
		.init(Double(pageRect.height), unit: .point)
	}

	public init(
		pageSize: PageSize = .letter,
		landscape: Bool = false,
		margins: Insets = .init(dx: 18.0, dy: 18.0)
	) {
		self.pageSize = pageSize
		self.landscape = landscape
		self.margins = margins
	}
}
