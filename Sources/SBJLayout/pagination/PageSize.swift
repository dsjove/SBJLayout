import Foundation

//TODO: Support custom size
//TODO: Add Category
public enum PageSize: Int, Sendable, Codable, CustomStringConvertible {
	// North American
	case letter = -1
	case legal = -2
	case tabloid = -3
	case ledger = -4
	case executive = -5

	// ISO 216 A-series sizes
	case a0 = 0
	case a1 = 1
	case a2 = 2
	case a3 = 3
	case a4 = 4
	case a5 = 5
	case a6 = 6

	public var size: CGSize {
		switch self {
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
		}
	}

	public var rect: CGRect {
		CGRect(origin: .zero, size: size)
	}

	//TODO: make margin an Insets
	public func rect(landscape: Bool, margin: CGSize) -> CGRect {
		let x = margin.width
		let y = margin.height
		let w = size.width - margin.width * 2
		let h = size.height - margin.height * 2
		return CGRect(
			x: landscape ? y : x,
			y: landscape ? x : y,
			width: landscape ? h : w,
			height: landscape ? w : h
		)
	}

	public var description: String {
		switch self {
		case .letter: "Letter"
		case .legal: "Legal"
		case .tabloid: "Tabloid"
		case .ledger: "Ledger"
		case .executive: "Executive"
		default: "A\(self.rawValue)"
		}
	}
}
