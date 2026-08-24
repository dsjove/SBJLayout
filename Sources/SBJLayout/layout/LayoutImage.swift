import CoreGraphics
import UIKit

/// A rendered image whose geometry is resolved inside an allocated layout rect.
///
/// When used as a `Panel.backgroundImage`, the panel deliberately does not
/// consult `measure(bounds:)`; the image is decorative and paints only after
/// the panel's layout has been resolved.
public struct LayoutImage: Renderable {
	public let cornerRadius: CGFloat
	public let aspect: Aspect
	public let image: UIImage?

	public init(
		_ image: UIImage?,
		aspect: Aspect = .fit,
		cornerRadius: CGFloat = 0.0
	) {
		self.cornerRadius = cornerRadius
		self.aspect = aspect
		self.image = image
	}

	public var isEmpty: Bool {
		image == nil
	}

	public func measure(bounds: CGSize) -> CGSize {
		aspect.apply(size: image?.size ?? .zero, in: bounds)
	}

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		if let image = image {
			let sized = aspect.apply(size: image.size, in: allocated.size)
			let placed = align.apply(size: sized, in: allocated)
			if let ctx = UIGraphicsGetCurrentContext() {
				ctx.saveGState()
				defer { ctx.restoreGState() }
				if cornerRadius > 0 {
					let path = CGPath(roundedRect: placed, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
					ctx.addPath(path)
					ctx.clip()
				}
				image.draw(in: placed)
			}
		}
	}
}
