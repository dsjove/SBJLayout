import CoreGraphics

/// Repeating visual and measured content associated with every physical page.
///
/// Background and overlay are draw-only chrome and do not affect pagination.
/// Header and footer are renderables; their measured heights are reserved from
/// the body content rectangle before pagination is calculated.
public struct PageChrome {
	public var background: (any Chrome)?
	public var header: (any Renderable)?
	public var footer: (any Renderable)?
	public var overlay: (any Chrome)?

	public var contentInsets: Insets
	public var headerGap: CGFloat
	public var footerGap: CGFloat

	public init(
		background: (any Chrome)? = nil,
		header: (any Renderable)? = nil,
		footer: (any Renderable)? = nil,
		overlay: (any Chrome)? = nil,
		contentInsets: Insets = .zero,
		headerGap: CGFloat = 0,
		footerGap: CGFloat = 0
	) {
		self.background = background
		self.header = header
		self.footer = footer
		self.overlay = overlay
		self.contentInsets = contentInsets
		self.headerGap = max(0, headerGap)
		self.footerGap = max(0, footerGap)
	}

	public static var none: PageChrome { PageChrome() }
}

struct ResolvedPageChrome {
	let pageRect: CGRect
	let printableRect: CGRect
	let chromeRect: CGRect
	let contentRect: CGRect
	let headerRect: CGRect?
	let footerRect: CGRect?
	let headerMeasured: CGSize?
	let footerMeasured: CGSize?
}
