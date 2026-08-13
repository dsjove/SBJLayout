import Foundation

public enum PageSize: Sendable, Codable, Hashable, CustomStringConvertible {
	public enum Category: String, Sendable, Codable, CaseIterable, CustomStringConvertible {
		case special
		case northAmerican
		case isoA
		case photo
		case custom

		public var description: String {
			switch self {
			case .special: "Special"
			case .northAmerican: "North American"
			case .isoA: "ISO A"
			case .photo: "Photo"
			case .custom: "Custom"
			}
		}
	}

	// Special
	case zero
	case unbounded

	// North American
	case letter
	case legal
	case tabloid
	case ledger
	case executive

	// ISO 216 A-series
	case a0
	case a1
	case a2
	case a3
	case a4
	case a5
	case a6

	// Common photographic print sizes
	case photo4x6
	case photo5x7
	case photo8x10
	case photo11x14
	case photo12x18
	case photo16x20
	case photo20x24
	case photo20x30
	case photo24x36

	case custom(width: CGFloat, height: CGFloat)

	public var category: Category {
		switch self {
		case .zero, .unbounded:
			.special
		case .letter, .legal, .tabloid, .ledger, .executive:
			.northAmerican
		case .a0, .a1, .a2, .a3, .a4, .a5, .a6:
			.isoA
		case .photo4x6, .photo5x7, .photo8x10, .photo11x14, .photo12x18,
			.photo16x20, .photo20x24, .photo20x30, .photo24x36:
			.photo
		case .custom:
			.custom
		}
	}

	public static let standard: [PageSize] =
		northAmerican + isoA + photo

	public static let special: [PageSize] = [.zero, .unbounded]
	public static let northAmerican: [PageSize] = [.letter, .legal, .tabloid, .ledger, .executive]
	public static let isoA: [PageSize] = [.a0, .a1, .a2, .a3, .a4, .a5, .a6]
	public static let photo: [PageSize] = [
		.photo4x6, .photo5x7, .photo8x10, .photo11x14, .photo12x18,
		.photo16x20, .photo20x24, .photo20x30, .photo24x36,
	]

	public static func sizes(in category: Category) -> [PageSize] {
		switch category {
		case .special: special
		case .northAmerican: northAmerican
		case .isoA: isoA
		case .photo: photo
		case .custom: []
		}
	}

	public var size: CGSize {
		switch self {
		case .zero:
			.zero
		case .unbounded:
			.unbounded
		case .letter:
			CGSize(width: 612, height: 792)       // 8.5 × 11 in
		case .legal:
			CGSize(width: 612, height: 1008)      // 8.5 × 14 in
		case .tabloid:
			CGSize(width: 792, height: 1224)      // 11 × 17 in
		case .ledger:
			CGSize(width: 1224, height: 792)      // 17 × 11 in
		case .executive:
			CGSize(width: 522, height: 756)       // 7.25 × 10.5 in
		case .a0:
			CGSize(width: 2384, height: 3370)
		case .a1:
			CGSize(width: 1684, height: 2384)
		case .a2:
			CGSize(width: 1191, height: 1684)
		case .a3:
			CGSize(width: 842, height: 1191)
		case .a4:
			CGSize(width: 595, height: 842)
		case .a5:
			CGSize(width: 420, height: 595)
		case .a6:
			CGSize(width: 298, height: 420)
		case .photo4x6:
			Self.inches(width: 4, height: 6)
		case .photo5x7:
			Self.inches(width: 5, height: 7)
		case .photo8x10:
			Self.inches(width: 8, height: 10)
		case .photo11x14:
			Self.inches(width: 11, height: 14)
		case .photo12x18:
			Self.inches(width: 12, height: 18)
		case .photo16x20:
			Self.inches(width: 16, height: 20)
		case .photo20x24:
			Self.inches(width: 20, height: 24)
		case .photo20x30:
			Self.inches(width: 20, height: 30)
		case .photo24x36:
			Self.inches(width: 24, height: 36)
		case let .custom(width, height):
			CGSize(width: width, height: height)
		}
	}

	public var rect: CGRect {
		CGRect(origin: .zero, size: size)
	}

	public func rect(landscape: Bool, margin: Insets) -> CGRect {
		let x = margin.left
		let y = margin.top
		let w = Self.subtractMargins(from: size.width, margin.left, margin.right)
		let h = Self.subtractMargins(from: size.height, margin.top, margin.bottom)
		return CGRect(
			x: landscape ? y : x,
			y: landscape ? x : y,
			width: landscape ? h : w,
			height: landscape ? w : h
		)
	}

	public var description: String {
		switch self {
		case .zero: "Zero"
		case .unbounded: "Unbounded"
		case .letter: "Letter"
		case .legal: "Legal"
		case .tabloid: "Tabloid"
		case .ledger: "Ledger"
		case .executive: "Executive"
		case .a0: "A0"
		case .a1: "A1"
		case .a2: "A2"
		case .a3: "A3"
		case .a4: "A4"
		case .a5: "A5"
		case .a6: "A6"
		case .photo4x6: "4 × 6 Photo"
		case .photo5x7: "5 × 7 Photo"
		case .photo8x10: "8 × 10 Photo"
		case .photo11x14: "11 × 14 Photo"
		case .photo12x18: "12 × 18 Photo"
		case .photo16x20: "16 × 20 Photo"
		case .photo20x24: "20 × 24 Photo"
		case .photo20x30: "20 × 30 Photo"
		case .photo24x36: "24 × 36 Photo"
		case let .custom(width, height): "Custom (\(width) × \(height))"
		}
	}

	private static func inches(width: CGFloat, height: CGFloat) -> CGSize {
		CGSize(width: width * 72, height: height * 72)
	}

	private static func subtractMargins(from value: CGFloat, _ first: CGFloat, _ second: CGFloat) -> CGFloat {
		value.isUnbounded ? value : value - first - second
	}
}
