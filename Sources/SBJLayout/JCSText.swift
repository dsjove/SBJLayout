import CoreGraphics
import UIKit

public struct JCSText: JCSLayoutElement {
	public let text: String?
	public let font: UIFont
	public let align: Alignment?
	public let lines: ClosedRange<Int>?
	private let content: NSMutableAttributedString?
	private let charMeasure: NSAttributedString?
// TODO: Bug - do copy-on-write for content member and cache measurement

	public init(
		size font: UIFont?,
		chars: Int? = nil,
		lines: Int = 1
	) {
		self.init(nil as String?, font: font, minChars: chars, lines: lines...lines)
	}

	public init(
		_ text: CustomStringConvertible?,
		font: UIFont?,
		color: UIColor?,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil
	) {
		self.init(text?.description, font: font, color: color, align: align, minChars: minChars, lines: lines)
	}

	public init(
		_ text: String?,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil
	) {
		let font = font ?? UIFont.systemFont(ofSize: 9.0)
		let color = color ?? UIColor.black
		self.text = text
		self.font = font
		self.align = align
		self.lines = lines

		if let text, !text.isEmpty {
			content = NSMutableAttributedString(string: text, attributes: [
				.font: font,
				.foregroundColor: color,
			])
		} else {
			content = nil
		}
		if let minChars {
			let text = String(repeating: "W", count: minChars)
			charMeasure = NSAttributedString(string: text, attributes: [
				.font: font,
			])
		} else {
			charMeasure = nil
		}
	}
	
	public func measure(bounds: CGSize = .unbounded) -> CGSize {
		guard let content else {
			if let charMeasure {
				return measure(bounds: bounds, str: charMeasure, lines: lines)
			} else if let lines {
				return .init(width: 0.0, height: ceil(CGFloat(lines.lowerBound) * font.lineHeight))
			} else {
				return .zero
			}
		}
		var measured = measure(bounds: bounds, str: content, lines: lines)
		if let charMeasure {
			let minChars = measure(bounds: bounds, str: charMeasure, lines: lines)
			measured = .init(
				width: max(measured.width, minChars.width),
				height: max(measured.height, minChars.height)
			)
		}
		return measured
	}

	private func measure(bounds: CGSize, str: NSAttributedString, lines: ClosedRange<Int>?) -> CGSize {
		var measured = str.boundingRect(
			with: bounds,
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			context: nil
		).integral.size

		if bounds.width != .unbounded {
			measured.width = ceil(bounds.width)
		}
		if let lines {
			if lines.lowerBound > 1 {
				let minHeight = ceil(CGFloat(lines.lowerBound) * font.lineHeight)
				measured.height = max(minHeight, measured.height)
			}
			if lines.upperBound > 0 && lines.upperBound != Int.max {
				let maxHeight = ceil(CGFloat(lines.upperBound) * font.lineHeight)
				measured.height = min(maxHeight, measured.height)
			}
		}
		return measured
	}

	public func draw(in allocated: CGRect, measured: CGSize, align: Alignment) {
		guard let content else { return }
		var r = allocated
		//NSAttributedString has alignment built into the attributes
		let align = self.align ?? align
		content.addAttribute(
			.paragraphStyle,
			value: {
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.alignment = align.textAlignment
				paragraphStyle.lineBreakMode = .byWordWrapping
				return paragraphStyle
			}(),
			range: NSRange(
				location: 0,
				length: content.length
			)
		)
		//NSAttributedString has no notion of vertical alignment
		if align.contains(.bottom) {
			let size = measure(bounds: allocated.size)
			r = align.apply(size: size, in: allocated).integral
		}
		content.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
	}
}
