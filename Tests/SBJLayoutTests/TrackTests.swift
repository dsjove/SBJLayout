import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Track")
struct TrackTests {
	@Test("Default aggregate returns the maximum candidate")
	func defaultAggregateUsesMaximum() {
		let track = Track()

		#expect(track.aggregate([10, 0, 25, 5]) == 25)
		#expect(track.aggregate([]) == nil)
	}

	@Test("Copy initializer replaces only the aggregate")
	func copyInitializerReplacesAggregate() {
		let original = Track(
			.fixed(12),
			align: .rightBottom,
			gap: 7
		)
		let copy = Track(original) { $0.reduce(0, +) }

		guard case .fixed(let length) = copy.length else {
			Issue.record("Expected copied track to remain fixed")
			return
		}
		#expect(length == 12)
		#expect(copy.align == original.align)
		#expect(copy.gap == original.gap)
		#expect(copy.aggregate([3, 4, 5]) == 12)
	}
}
