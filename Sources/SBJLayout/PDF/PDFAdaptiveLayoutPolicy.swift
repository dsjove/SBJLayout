#if !os(watchOS)
import CoreGraphics
import PDFKit

/// Geometry-only policy for choosing whether a PDF presentation should show one
/// page or a two-page spread.
///
/// The policy intentionally knows nothing about device idiom, window role, editor
/// state, or device posture. Callers decide *when* adaptive behavior is desirable;
/// this type only answers how many pages fit the supplied viewport.
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

/// The direction in which the user moves through PDF pages.
public enum PDFPageFlow: Sendable, Equatable {
	/// Pages form one vertically scrolling document.
	case verticalScrolling

	/// Pages advance horizontally, one page or spread at a time.
	case horizontalPaging
}

/// How many PDF pages are presented at once.
public enum PDFPageDisplay: Sendable, Equatable {
	case singlePage
	case twoPage
}

/// Explicit PDF viewing behavior used by ``StablePDFView`` and
/// ``PDFPresentationView``.
///
/// Device posture belongs to the application. SBJLayout receives the resulting PDF
/// behavior in this device-neutral vocabulary.
public enum PDFPresentationLayout: Sendable, Equatable {
	/// One page wide, vertically continuous scrolling.
	case verticalSinglePage

	/// One page at a time with horizontal paging.
	case horizontalSinglePage

	/// Two-page spreads with horizontal paging.
	case horizontalTwoPage

	/// Choose between vertical single-page and horizontal two-page presentation
	/// from the available geometry.
	case adaptive(PDFAdaptiveLayoutPolicy = .init())

	public var pageFlow: PDFPageFlow {
		switch self {
		case .verticalSinglePage:
			return .verticalScrolling
		case .horizontalSinglePage, .horizontalTwoPage:
			return .horizontalPaging
		case .adaptive:
			// Adaptive flow depends on the resolved display count. This value describes
			// the single-page side of the policy and should not be used to resolve it.
			return .verticalScrolling
		}
	}

	public var pageDisplay: PDFPageDisplay? {
		switch self {
		case .verticalSinglePage, .horizontalSinglePage:
			return .singlePage
		case .horizontalTwoPage:
			return .twoPage
		case .adaptive:
			return nil
		}
	}
}

#endif
