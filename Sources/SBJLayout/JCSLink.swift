#if !os(watchOS)
import CoreGraphics
import Foundation
import UIKit

/// Adds a PDF link annotation over another renderable without changing its
/// measurement or drawing behavior.
///
/// This keeps hyperlink semantics in SBJLayout rather than forcing PDF clients
/// to reach into the underlying Core Graphics PDF context themselves.
public struct JCSLink<Content: Renderable>: Renderable {
    public let url: URL
    public let content: Content

    public init(_ url: URL, content: Content) {
        self.url = url
        self.content = content
    }

    public func measure(bounds: CGSize) -> CGSize {
        content.measure(bounds: bounds)
    }

    public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
        let frame = align.apply(size: measured, in: allocated)
        content.render(in: allocated, measured: measured, align: align)
        UIGraphicsGetCurrentContext()?.setURL(url as CFURL, for: frame)
    }
}
#endif
