import CoreGraphics
import UIKit
import SBJFoundation

public struct JCSText: Renderable {
	public let text: String?
	public let font: UIFont
	public let align: Alignment?
	public let lines: ClosedRange<Int>?
	public let lineBreakMode: NSLineBreakMode
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
		lines: ClosedRange<Int>? = nil,
		lineBreakMode: NSLineBreakMode = .byWordWrapping
	) {
		self.init(verbatim: text?.description, font: font, color: color, align: align, minChars: minChars, lines: lines, lineBreakMode: lineBreakMode)
	}

	public init(
		_ jargon: String?,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil,
		lineBreakMode: NSLineBreakMode = .byWordWrapping
	) {
		self.init(
			verbatim: Self.jargon.text(jargon),
			font: font,
			color: color,
			align: align,
			minChars: minChars,
			lines: lines,
			lineBreakMode: lineBreakMode
		)
	}

	public init<Value: Sendable>(
		_ jargon: String?,
		value: Value,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil,
		lineBreakMode: NSLineBreakMode = .byWordWrapping
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
			lines: lines,
			lineBreakMode: lineBreakMode
		)
	}

	public init(
		verbatim text: String?,
		font: UIFont? = nil,
		color: UIColor? = nil,
		align: Alignment? = nil,
		minChars: Int? = nil,
		lines: ClosedRange<Int>? = nil,
		lineBreakMode: NSLineBreakMode = .byWordWrapping
	) {
		let font = font ?? UIFont.systemFont(ofSize: 9.0)
		let color = color ?? UIColor.black
		self.text = text
		self.font = font
		self.align = align
		self.lines = lines
		self.lineBreakMode = lineBreakMode
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
	
	public func minimumMeasure(bounds: CGSize) -> CGSize {
		// Only wrapping modes have a smaller content-driven width than their
		// preferred measurement. Clipping and truncation are presentation policies,
		// not wrapping opportunities, so preserve their existing measurement.
		guard lineBreakMode == .byWordWrapping || lineBreakMode == .byCharWrapping else {
			return measure(bounds: bounds)
		}

		guard let content else {
			if let charMeasure {
				return minimumCharacterMeasure(bounds: bounds, str: charMeasure, lines: lines)
			} else if let lines {
				return .init(width: 0.0, height: ceil(CGFloat(lines.lowerBound) * font.lineHeight))
			} else {
				return .zero
			}
		}

		var measured = minimumMeasure(bounds: bounds, str: content, lines: lines)
		if let charMeasure {
			let minChars = minimumCharacterMeasure(bounds: bounds, str: charMeasure, lines: lines)
			measured = .init(
				width: max(measured.width, minChars.width),
				height: max(measured.height, minChars.height)
			)
		}
		return measured
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
		var measured = rawMeasure(bounds: bounds, str: str, lines: lines)

		if bounds.width != .unbounded {
			measured.width = ceil(bounds.width)
		}
		return measured
	}

	private func minimumCharacterMeasure(bounds: CGSize, str: NSAttributedString, lines: ClosedRange<Int>?) -> CGSize {
		// minChars is an explicit adaptive horizontal reserve. Unlike ordinary
		// wrapping content, the synthetic characters are not allowed to collapse
		// to the minimum wrapping probe. Measure their natural width, then respect
		// any finite bound supplied by the caller.
		let natural = rawMeasure(bounds: .unbounded, str: str, lines: lines)
		let width = bounds.width == .unbounded
			? natural.width
			: min(max(bounds.width, 0), natural.width)

		var measuredBounds = bounds
		measuredBounds.width = max(width, CGFloat.ulpOfOne)
		var measured = rawMeasure(bounds: measuredBounds, str: str, lines: lines)
		measured.width = ceil(width)
		return measured
	}

	private func minimumMeasure(bounds: CGSize, str: NSAttributedString, lines: ClosedRange<Int>?) -> CGSize {
		let naturalMinimumWidth: CGFloat
		switch lineBreakMode {
		case .byWordWrapping:
			naturalMinimumWidth = minimumWordWidth(str)
		case .byCharWrapping:
			naturalMinimumWidth = minimumGraphemeWidth(str)
		default:
			return measure(bounds: bounds, str: str, lines: lines)
		}

		let width = bounds.width == .unbounded
			? naturalMinimumWidth
			: min(max(bounds.width, 0), naturalMinimumWidth)

		guard width > 0 else {
			if let lines {
				return .init(width: 0, height: ceil(CGFloat(lines.lowerBound) * font.lineHeight))
			}
			return .zero
		}

		var minimumBounds = bounds
		minimumBounds.width = width
		var measured = rawMeasure(bounds: minimumBounds, str: str, lines: lines)
		measured.width = ceil(width)
		return measured
	}

	private func minimumWordWidth(_ str: NSAttributedString) -> CGFloat {
		let text = str.string
		var widest: CGFloat = 0
		var foundWord = false

		text.enumerateSubstrings(
			in: text.startIndex..<text.endIndex,
			options: [.byWords, .substringNotRequired]
		) { _, range, _, _ in
			foundWord = true
			let token = str.attributedSubstring(from: NSRange(range, in: text))
			widest = max(widest, self.rawMeasure(bounds: .unbounded, str: token, lines: nil).width)
		}

		// Some strings (for example punctuation-only content) have no Foundation
		// "words". They still need a nonzero minimum, so fall back to the widest
		// grapheme rather than collapsing to zero.
		return foundWord ? widest : minimumGraphemeWidth(str)
	}

	private func minimumGraphemeWidth(_ str: NSAttributedString) -> CGFloat {
		let text = str.string
		var widest: CGFloat = 0
		var index = text.startIndex

		while index < text.endIndex {
			let next = text.index(after: index)
			let range = index..<next
			let token = str.attributedSubstring(from: NSRange(range, in: text))
			widest = max(widest, rawMeasure(bounds: .unbounded, str: token, lines: nil).width)
			index = next
		}

		return widest
	}

	private func rawMeasure(bounds: CGSize, str: NSAttributedString, lines: ClosedRange<Int>?) -> CGSize {
		var measured = str.boundingRect(
			with: bounds,
			options: [.usesLineFragmentOrigin, .usesFontLeading],
			context: nil
		).integral.size

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
				paragraphStyle.lineBreakMode = lineBreakMode
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
