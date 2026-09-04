import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("TrackFactory")
struct TrackFactoryTests {
	private func fixedValue(_ size: TrackSize) -> CGFloat? {
		guard case .fixed(let value) = size else { return nil }
		return value
	}

	@Test("Length initializer creates tracks with the supplied properties")
	func lengthInitializer() {
		let factory = TrackFactory(
			.fixed(12),
			align: .rightBottom,
			gap: 7,
			minCount: 2,
			maxCount: 4
		)
		let track = factory.def(0)

		#expect(factory.minCount == 2)
		#expect(factory.maxCount == 4)
		#expect(fixedValue(track.length) == 12)
		#expect(track.align == .rightBottom)
		#expect(track.gap == 7)
	}

	@Test("Column initializer produces exactly one track")
	func columnInitializer() {
		let track = Track(.fixed(15), align: .center, gap: 3)
		let factory = TrackFactory(col: track)

		#expect(factory.minCount == 1)
		#expect(factory.maxCount == 1)
		#expect(fixedValue(factory.def(0).length) == 15)
		#expect(factory.def(0).align == .center)
		#expect(factory.def(0).gap == 3)
	}

	@Test("Row initializer preserves its count limits")
	func rowInitializer() {
		let track = Track(.fixed(9), align: .bottom, gap: 4)
		let factory = TrackFactory(row: track, minCount: 2, maxCount: 5)

		#expect(factory.minCount == 2)
		#expect(factory.maxCount == 5)
		#expect(fixedValue(factory.def(3).length) == 9)
		#expect(factory.def(3).align == .bottom)
		#expect(factory.def(3).gap == 4)
	}

	@Test("Array initializer returns tracks in array order by default")
	func arrayInitializer() {
		let factory = TrackFactory([
			Track(.fixed(10)),
			Track(.fixed(20)),
			Track(.fixed(30)),
		])

		#expect(factory.minCount == 1)
		#expect(factory.maxCount == 3)
		#expect((0..<3).map { fixedValue(factory.def($0).length) } == [10, 20, 30])
	}

	@Test("Array mapping transforms each requested index")
	func mappedArrayInitializer() {
		let tracks = [
			Track(.fixed(10)),
			Track(.fixed(20)),
			Track(.fixed(30)),
		]
		var requestedIndices: [Int] = []
		let factory = TrackFactory(tracks) { index in
			requestedIndices.append(index)
			return [2, 0, 1][index]
		}

		let lengths = (0..<3).map { fixedValue(factory.def($0).length) }

		#expect(requestedIndices == [0, 1, 2])
		#expect(lengths == [30, 10, 20])
	}

	@Test("Definition initializer receives the requested index")
	func definitionInitializer() {
		var requestedIndices: [Int] = []
		let factory = TrackFactory(minCount: 1, maxCount: 3) { index in
			requestedIndices.append(index)
			return Track(.fixed(CGFloat(index + 1)))
		}

		let lengths = (0..<3).map { fixedValue(factory.def($0).length) }

		#expect(requestedIndices == [0, 1, 2])
		#expect(lengths == [1, 2, 3])
	}

	@Test("Definition initializer delegates placeholder sentinel to the client")
	func definitionInitializerDelegatesPlaceholderSentinel() {
		var requestedIndices: [Int] = []
		let factory = TrackFactory(minCount: 2, maxCount: 4) { index in
			requestedIndices.append(index)
			return index == TrackFactory.placeholderIndex
				? Track(.intrinsic(min: 44))
				: Track(.intrinsic())
		}

		let placeholder = factory.def(TrackFactory.placeholderIndex)

		#expect(requestedIndices == [TrackFactory.placeholderIndex])
		guard case .intrinsic(_, let minimum) = placeholder.length else {
			Issue.record("Expected an intrinsic placeholder track")
			return
		}
		#expect(minimum == 44)
	}

}
