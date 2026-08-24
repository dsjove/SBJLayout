import CoreGraphics
import Testing
import UIKit
@testable import SBJLayout

@Suite("Panel")
struct PanelTests {
	private struct FixedRenderable: Renderable {
		let size: CGSize

		func measure(bounds: CGSize) -> CGSize { size }
		func render(in allocated: CGRect, measured: CGSize, align: Alignment) {}
	}

	@Test("Background image does not participate in measurement")
	func backgroundImageDoesNotParticipateInMeasurement() {
		let content = FixedRenderable(size: CGSize(width: 80, height: 30))
		let image = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 400)).image { _ in }
		let bounds = CGSize(width: 300, height: 200)

		let withoutImage = Panel(insets: .zero, content: content)
		let withImage = Panel(
			insets: .zero,
			backgroundImage: LayoutImage(image, aspect: .fill),
			content: content
		)

		#expect(withoutImage.measure(bounds: bounds) == CGSize(width: 80, height: 30))
		#expect(withImage.measure(bounds: bounds) == withoutImage.measure(bounds: bounds))
	}

	@Test("Background image does not change inset measurement")
	func backgroundImageDoesNotChangeInsetMeasurement() {
		let content = FixedRenderable(size: CGSize(width: 80, height: 30))
		let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 1000)).image { _ in }
		let insets = Insets(dx: 7, dy: 5)
		let bounds = CGSize(width: 300, height: 200)

		let panel = Panel(
			insets: insets,
			backgroundImage: LayoutImage(image, aspect: .fit),
			content: content
		)

		#expect(panel.measure(bounds: bounds) == CGSize(width: 94, height: 40))
	}
}
