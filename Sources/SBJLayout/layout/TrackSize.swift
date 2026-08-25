import CoreGraphics

public enum TrackSize: CustomStringConvertible {
// Fully non-computed size
	case fixed(_ value: CGFloat)
// Computes intrinsic size given bounds, then applies min
	case intrinsic(bound: CGFloat = .unbounded, min: CGFloat? = nil)
// Fraction is of complete available space, honoring min/max
	case fill(_ fraction: CGFloat? = nil, min: CGFloat = 0, max: CGFloat = .unbounded, ifContent: Bool = false)
// Given uniform only elements, use the reduce function
	case uniform(_ reduce: (CGFloat, CGFloat)->CGFloat = max)

	public var description: String {
		switch self {
		case .fixed(let value):
			"fixed(\(value.unboundedDescription))"
		case .intrinsic(let bound, let min):
			"intrinsic(\(min ?? 0.0)...\(bound.unboundedDescription))"
		case .uniform:
			"uniform(∑)"
		case .fill(let fraction, let minimum, let maximum, let ifContent):
			"fill\(fraction?.description ?? "1/C") \(minimum)…\(maximum.unboundedDescription)\(ifContent ? " ifContent" : "")"
		}
	}
}
