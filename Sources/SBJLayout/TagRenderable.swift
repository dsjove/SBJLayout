import CoreGraphics
import UIKit
import SBJFoundation

//TODO: use JSCRect and JCSText for impl
//TODO: implement TagGroup using JCSGrid
//TODO: extend TagUser for renderable

/// Core Graphics representation of a semantic tag.
///
/// Tag storage and SwiftUI controls live in SBJFoundation. Printable rendering
/// belongs in SBJLayout so clients do not need their own PDF-only tag geometry.
public struct TagRenderable: Renderable {
    public let displayName: String
    public let color: CodableColor
    public let isPrimary: Bool

    public init(displayName: String, color: CodableColor, isPrimary: Bool = false) {
        self.displayName = displayName
        self.color = color
        self.isPrimary = isPrimary
    }

    private var horizontalPadding: CGFloat { 8 }
    private var verticalPadding: CGFloat { 2 }
    private var cornerRadius: CGFloat { 8 }
    private var reservedStrokeWidth: CGFloat { 2 }
    private var strokeWidth: CGFloat { isPrimary ? reservedStrokeWidth : 0 }

    private var font: UIFont {
        let base = UIFont.preferredFont(forTextStyle: .caption1)
        guard let descriptor = base.fontDescriptor.withSymbolicTraits(.traitBold) else { return base }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    private var foregroundColor: UIColor {
        color.uiColor.isLight ? .black : .white
    }

    public func measure(bounds: CGSize) -> CGSize {
        guard !displayName.isEmpty else { return .zero }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let content = NSAttributedString(string: displayName, attributes: [
            .font: font,
            .paragraphStyle: paragraph,
        ])

        let availableWidth: CGFloat = {
            guard bounds.width != .unbounded else { return .greatestFiniteMagnitude }
            return max(0, bounds.width - horizontalPadding * 2 - reservedStrokeWidth)
        }()
        let availableHeight: CGFloat = {
            guard bounds.height != .unbounded else { return .greatestFiniteMagnitude }
            return max(0, bounds.height - verticalPadding * 2 - reservedStrokeWidth)
        }()

        let measured = content.boundingRect(
            with: CGSize(width: availableWidth, height: availableHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.size

        return CGSize(
            width: ceil(measured.width + horizontalPadding * 2 + reservedStrokeWidth),
            height: ceil(measured.height + verticalPadding * 2 + reservedStrokeWidth)
        )
    }

    public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
        guard !displayName.isEmpty else { return }
        let rect = align.apply(size: measured, in: allocated)
        let inset = reservedStrokeWidth / 2
        let drawingRect = rect.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(roundedRect: drawingRect, cornerRadius: cornerRadius)

        color.uiColor.setFill()
        path.fill()

        if strokeWidth > 0 {
            UIColor.black.setStroke()
            path.lineWidth = strokeWidth
            path.stroke()
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let content = NSAttributedString(string: displayName, attributes: [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraph,
        ])
        let textRect = drawingRect.insetBy(dx: horizontalPadding, dy: verticalPadding)
        let textSize = content.boundingRect(
            with: CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).integral.size
        let drawRect = CGRect(
            x: textRect.minX,
            y: textRect.midY - textSize.height / 2,
            width: textRect.width,
            height: textSize.height
        )
        content.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
}

public extension Tagging {
    func renderable(isPrimary: Bool = false) -> TagRenderable {
        TagRenderable(displayName: displayName, color: color, isPrimary: isPrimary)
    }
}
