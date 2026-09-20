#if !os(watchOS)
import CoreGraphics
import PDFKit

/// Geometry-only policy for choosing the most useful continuous PDF page arrangement.
///
/// The policy intentionally knows nothing about device idiom, window role, editor state,
/// or platform pose. It receives only the viewport and the PDF page geometry.
public struct PDFAdaptiveLayoutPolicy: Sendable, Equatable {
	public var minimumTwoUpPageWidth: CGFloat
	public var hysteresis: CGFloat

	public init(
		minimumTwoUpPageWidth: CGFloat = 320,
		hysteresis: CGFloat = 0.10
	) {
		self.minimumTwoUpPageWidth = minimumTwoUpPageWidth
		self.hysteresis = hysteresis
	}

	public func displayMode(
		viewport: CGSize,
		pageSize: CGSize,
		current: PDFDisplayMode
	) -> PDFDisplayMode {
		guard viewport.width > 0,
			viewport.height > 0,
			pageSize.width > 0,
			pageSize.height > 0
		else { return .singlePageContinuous }

		let viewportAspect = viewport.width / viewport.height
		let pageAspect = pageSize.width / pageSize.height
		let spreadAspect = pageAspect * 2
		let neutralThreshold = sqrt(pageAspect * spreadAspect)
		let widthAllowsTwoUp = viewport.width / 2 >= minimumTwoUpPageWidth

		guard widthAllowsTwoUp else { return .singlePageContinuous }

		let clampedHysteresis = max(0, hysteresis)
		let switchToTwoUp = neutralThreshold * (1 + clampedHysteresis)
		let switchToSingle = neutralThreshold / (1 + clampedHysteresis)

		switch current {
		case .twoUp:
			return viewportAspect < switchToSingle ? .singlePageContinuous : .twoUp
		default:
			return viewportAspect > switchToTwoUp ? .twoUp : .singlePageContinuous
		}
	}
}

/// How a stable PDF host chooses page arrangement inside its available rectangle.
public enum PDFContinuousLayout: Sendable, Equatable {
	case singlePage
	case adaptive(PDFAdaptiveLayoutPolicy = .init())
}
#endif
