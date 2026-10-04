#if !os(watchOS)
import CoreGraphics
import PDFKit
import QuartzCore
import UIKit

/// Stable geometry for one text-search result. PDFKit selections are intentionally
/// not retained: page-view-controller turns can rebuild PDFKit's presentation objects.
/// Each fragment is stored in PDF page coordinates and resolved against the current
/// document page only when it is drawn or navigated to.
struct PDFSearchMatch {
	struct Fragment {
		let pageIndex: Int
		let pageRect: CGRect
	}

	let fragments: [Fragment]

	var firstFragment: Fragment? { fragments.first }
}

/// Visual treatment for PDF text-search results.
///
/// `highlight` is drawn for every visible result. `animatedHighlight` is drawn
/// temporarily over the current result after PDFKit has navigated to it.
public struct PDFSearchPresentationStyle {
	public var highlight: JCSRect
	public var animatedHighlight: JCSRect
	public var padding: CGFloat
	public var animationDuration: TimeInterval
	public var animationInitialScale: CGFloat

	public init(
		highlight: JCSRect = JCSRect(
			fill: UIColor.systemYellow.withAlphaComponent(0.45),
			stroke: UIColor.systemOrange.withAlphaComponent(0.95),
			lineWidth: 2,
			radius: 3
		),
		animatedHighlight: JCSRect = JCSRect(
			fill: UIColor.systemOrange.withAlphaComponent(0.34),
			stroke: UIColor.systemRed,
			lineWidth: 4,
			radius: 4
		),
		padding: CGFloat = 1.5,
		animationDuration: TimeInterval = 1.0,
		animationInitialScale: CGFloat = 1.25
	) {
		self.highlight = highlight
		self.animatedHighlight = animatedHighlight
		self.padding = padding
		self.animationDuration = animationDuration
		self.animationInitialScale = animationInitialScale
	}
}

@MainActor
final class PDFSearchOverlayView: UIView {
	weak var pdfView: PDFView?
	private var matches: [PDFSearchMatch] = []
	private var style = PDFSearchPresentationStyle()
	private var displayLink: CADisplayLink?
	private var animationLayers: [CAShapeLayer] = []
	private var animationGeneration = UUID()

	init(pdfView: PDFView) {
		self.pdfView = pdfView
		super.init(frame: pdfView.bounds)
		backgroundColor = .clear
		isOpaque = false
		isUserInteractionEnabled = false
		contentMode = .redraw
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func present(_ matches: [PDFSearchMatch], style: PDFSearchPresentationStyle) {
		self.matches = matches
		self.style = style
		setNeedsDisplay()
		if matches.isEmpty {
			stopDisplayLink()
		} else {
			startDisplayLink()
		}
	}

	func clear() {
		matches.removeAll()
		clearAnimation()
		stopDisplayLink()
		setNeedsDisplay()
	}

	func animate(_ match: PDFSearchMatch) {
		guard let pdfView else { return }
		clearAnimation()
		let generation = UUID()
		animationGeneration = generation

		let rects = viewRects(for: match, in: pdfView)
		guard !rects.isEmpty else { return }

		let appearance = style.animatedHighlight
		for rect in rects {
			let layer = CAShapeLayer()
			layer.frame = rect
			layer.path = UIBezierPath(
				roundedRect: CGRect(origin: .zero, size: rect.size),
				cornerRadius: appearance.radius
			).cgPath
			layer.fillColor = appearance.fill.cgColor
			layer.strokeColor = appearance.stroke.cgColor
			layer.lineWidth = appearance.lineWidth
			layer.opacity = 0
			self.layer.addSublayer(layer)
			animationLayers.append(layer)

			let scale = CABasicAnimation(keyPath: "transform.scale")
			scale.fromValue = style.animationInitialScale
			scale.toValue = 1

			let opacity = CAKeyframeAnimation(keyPath: "opacity")
			opacity.values = [0.15, 1.0, 1.0, 0.0]
			opacity.keyTimes = [0.0, 0.18, 0.72, 1.0]

			let group = CAAnimationGroup()
			group.animations = [scale, opacity]
			group.duration = style.animationDuration
			group.timingFunction = CAMediaTimingFunction(name: .easeOut)
			group.isRemovedOnCompletion = true
			layer.add(group, forKey: "searchPulse")
		}

		let duration = style.animationDuration
		Task { @MainActor [weak self] in
			try? await Task.sleep(for: .seconds(duration))
			guard let self, self.animationGeneration == generation else { return }
			self.clearAnimation()
		}
	}

	override func draw(_ rect: CGRect) {
		guard let pdfView, !matches.isEmpty, let document = pdfView.document else { return }
		let visiblePageIndices = Set(pdfView.visiblePages.compactMap { page -> Int? in
			let index = document.index(for: page)
			return index == NSNotFound ? nil : index
		})
		guard !visiblePageIndices.isEmpty else { return }

		for match in matches where match.fragments.contains(where: { visiblePageIndices.contains($0.pageIndex) }) {
			for resultRect in viewRects(for: match, in: pdfView, visiblePageIndices: visiblePageIndices)
			where resultRect.intersects(bounds) {
				style.highlight.draw(in: resultRect)
			}
		}
	}

	private func viewRects(
		for match: PDFSearchMatch,
		in pdfView: PDFView,
		visiblePageIndices: Set<Int>? = nil
	) -> [CGRect] {
		guard let document = pdfView.document else { return [] }
		return match.fragments.compactMap { fragment in
			if let visiblePageIndices, !visiblePageIndices.contains(fragment.pageIndex) { return nil }
			guard fragment.pageIndex >= 0,
				fragment.pageIndex < document.pageCount,
				let page = document.page(at: fragment.pageIndex),
				!fragment.pageRect.isNull,
				fragment.pageRect.width > 0,
				fragment.pageRect.height > 0
			else { return nil }

			let converted = pdfView.convert(fragment.pageRect, from: page)
			let padded = converted.insetBy(dx: -style.padding, dy: -style.padding)
			return padded.intersection(bounds)
		}.filter { !$0.isNull && $0.width > 1 && $0.height > 1 }
	}

	private func startDisplayLink() {
		guard displayLink == nil else { return }
		let displayLink = CADisplayLink(target: self, selector: #selector(refreshForViewportChange))
		displayLink.add(to: .main, forMode: .common)
		self.displayLink = displayLink
	}

	private func stopDisplayLink() {
		displayLink?.invalidate()
		displayLink = nil
	}

	@objc private func refreshForViewportChange() {
		guard let pdfView else {
			stopDisplayLink()
			return
		}
		if frame != pdfView.bounds {
			frame = pdfView.bounds
		}
		setNeedsDisplay()
	}

	private func clearAnimation() {
		animationGeneration = UUID()
		animationLayers.forEach {
			$0.removeAllAnimations()
			$0.removeFromSuperlayer()
		}
		animationLayers.removeAll()
	}
}
#endif
