import CoreGraphics
import UIKit

extension String {
	public func limitingExplicitLines(to maxLines: Int?) -> String {
		guard
			let maxLines,
			maxLines > 0,
			maxLines != Int.max
		else {
			return self
		}
		var lineCount = 1
		for index in indices {
			guard self[index] == "\n" else {
				continue
			}
			if lineCount == maxLines {
				return String(self[..<index])
			}
			lineCount += 1
		}
		return self
	}
}

public struct JCSText: Renderable {
	public let text: String?
	public let font: UIFont
	public let align: Alignment?
	public let lines: ClosedRange<Int>?
	private let content: NSAttributedString?
	private let charMeasure: NSAttributedString?
// Immutable attributed content preserves JCSText value semantics; render works on a private mutable copy.

	public init(
		size font: UIFont?,
		chars: Int? = nil,
		lines: Int = 1
	) {
		self.init(verbatim: nil, font: font, minChars: chars, lines: lines...lines)
	}

	public init(
		_ text: CustomStringConvertible?,
		font: UIFont?,
		color: UIColor?,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil
	) {
		self.init(verbatim: text?.description, font: font, color: color, align: align, minChars: minChars, lines: lines)
	}

	public init(
		_ jargon: String?,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil
	) {
		self.init(
			verbatim: Self.jargon.text(jargon),
			font: font,
			color: color,
			align: align,
			minChars: minChars,
			lines: lines
		)
	}

	public init<Value: Sendable>(
		_ jargon: String?,
		value: Value,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil
	) {
		let text = jargon.map { key in
			Self.jargon.format(key, value: value) ?? String(describing: value)
		}
		self.init(
			verbatim: text,
			font: font,
			color: color,
			align: align,
			minChars: minChars,
			lines: lines
		)
	}

	public init(
		verbatim text: String?,
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
		let text = text?.limitingExplicitLines(to: lines?.upperBound)

		if let text, !text.isEmpty {
			content = NSAttributedString(string: text, attributes: [
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

	public func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
		guard let content else { return }
		let renderedContent = NSMutableAttributedString(attributedString: content)
		var r = allocated
		//NSAttributedString has alignment built into the attributes
		let align = self.align ?? align
		renderedContent.addAttribute(
			.paragraphStyle,
			value: {
				let paragraphStyle = NSMutableParagraphStyle()
				paragraphStyle.alignment = align.textAlignment
				paragraphStyle.lineBreakMode = .byWordWrapping
				return paragraphStyle
			}(),
			range: NSRange(
				location: 0,
				length: renderedContent.length
			)
		)
		//NSAttributedString has no notion of vertical alignment
		if align.contains(.bottom) {
			let size = measure(bounds: allocated.size)
			r = align.apply(size: size, in: allocated).integral
		}
		renderedContent.draw(with: r, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
	}
}
