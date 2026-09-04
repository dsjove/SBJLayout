import Testing
import CoreGraphics
@testable import SBJLayout

@Suite("TrackLayout")
struct TrackLayoutTests {
    private let accuracy: CGFloat = 0.0001

    private func apply(
        _ widths: TrackLayout,
        available: CGFloat = .unbounded,
        intrinsicValues: [CGFloat] = []
    ) {
        widths.apply(available: available) { index, _, _ in
            guard intrinsicValues.indices.contains(index) else { return 0 }
            return intrinsicValues[index]
        }
    }

    private func expectEqual(_ actual: CGFloat, _ expected: CGFloat) {
        #expect(abs(actual - expected) <= accuracy)
    }

    private func expectEqual(_ actual: [CGFloat], _ expected: [CGFloat]) {
        #expect(actual.count == expected.count)
        for (actualValue, expectedValue) in zip(actual, expected) {
            expectEqual(actualValue, expectedValue)
        }
    }

    // MARK: - Baseline sizing

    @Test
    func testFixedTightLayoutAddsLengths() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(20)),
                Track(.fixed(30)),
                Track(.fixed(40))
            ],
            layout: .tight
        )

        apply(widths)

        expectEqual(widths.lengths, [20, 30, 40])
        expectEqual(widths.offsets, [0, 20, 50])
        expectEqual(widths.size, 90)
    }

    @Test
    func testGapLayoutOmitsTrailingGap() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(20), gap: 3),
                Track(.fixed(30), gap: 5),
                Track(.fixed(40), gap: 7)
            ],
            layout: .gaps
        )

        apply(widths)

        // 20 + 3 + 30 + 5 + 40; the last element's gap is omitted.
        expectEqual(widths.offsets, [0, 23, 58])
        expectEqual(widths.size, 98)
    }

    @Test
    func testGapLayoutSkipsZeroLengthElements() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(20), gap: 3),
                Track(.fixed(0), gap: 100),
                Track(.fixed(30), gap: 5)
            ],
            layout: .gaps
        )

        apply(widths)

        expectEqual(widths.offsets, [0, 20, 23])
        expectEqual(widths.size, 53)
    }

    @Test
    func testStackLayoutUsesLargestLength() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(20)),
                Track(.fixed(50)),
                Track(.fixed(30))
            ],
            layout: .stack
        )

        apply(widths)

        expectEqual(widths.offsets, [0, 0, 0])
        expectEqual(widths.size, 50)
    }

    // MARK: - Intrinsic and uniform

    @Test
    func testIntrinsicUsesProvidedBoundAndMinimum() {
        var receivedBounds: [CGFloat] = []
        let widths = TrackLayout(
            tracks: [
                Track(.intrinsic(bound: 80, min: 25)),
                Track(.intrinsic(bound: 40, min: 25))
            ],
            layout: .tight
        )

        widths.apply { index, _, bound in
            receivedBounds.append(bound)
            return index == 0 ? 10 : 35
        }

        expectEqual(widths.lengths, [25, 35])
        expectEqual(widths.offsets, [0, 25])
        expectEqual(receivedBounds, [80, 40])
        expectEqual(widths.size, 60)
    }

    @Test
    func testIntrinsicMayExceedSuggestedBound() {
        let widths = TrackLayout(
            tracks: [Track(.intrinsic(bound: 40))],
            layout: .tight
        )

        widths.apply { _, _, bound in
            #expect(bound == 40)
            return 65
        }

        expectEqual(widths.lengths, [65])
        expectEqual(widths.size, 65)
    }

    @Test
    func testUniformDefaultsToLargestUniformLength() {
        let widths = TrackLayout(
            tracks: [
                Track(.uniform()),
                Track(.intrinsic()),
                Track(.fixed(40)),
                Track(.uniform())
            ],
            layout: .tight
        )

        apply(widths, intrinsicValues: [10, 25, 0, 30])

        expectEqual(widths.lengths, [30, 25, 40, 30])
        expectEqual(widths.offsets, [0, 30, 55, 95])
    }

    @Test
    func testUniformSupportsCustomReducerWithoutRepeatingFirstValue() {
        let widths = TrackLayout(
            tracks: [
                Track(.uniform(+)),
                Track(.uniform(+)),
                Track(.fixed(20))
            ],
            layout: .tight
        )

        apply(widths, intrinsicValues: [10, 15, 0])

        expectEqual(widths.lengths, [25, 25, 20])
        expectEqual(widths.offsets, [0, 25, 50])
    }

    // MARK: - Linear fill

    @Test
    func testSingleFillConsumesAvailableGrowth() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 200])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 300)
    }

    @Test
    func testEqualFillsSplitAvailableGrowth() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill()),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 100, 100])
        expectEqual(widths.offsets, [0, 100, 200])
        expectEqual(widths.size, 300)
    }

    @Test
    func testFillMinimumConstrainsFractionOfAvailableFillSpace() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill(min: 50))
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 200])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 300)
    }

    @Test
    func testFillMaximumLimitsGrowth() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill(max: 75))
            ],
            layout: .tight
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [100, 75])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 175)
    }

    @Test
    func testExplicitFractionsCannotExceedRemainingSpace() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(0.75)),
                Track(.fill(0.75))
            ],
            layout: .tight
        )

        apply(widths, available: 200)

        expectEqual(widths.lengths, [150, 50])
        expectEqual(widths.offsets, [0, 150])
        expectEqual(widths.size, 200)
    }

    @Test
    func testConditionalFillCollapsesWithoutContent() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(ifContent: true), gap: 12),
                Track(.fixed(80))
            ],
            layout: .gaps
        )

        apply(widths, available: 300, intrinsicValues: [0, 0])

        expectEqual(widths.lengths, [0, 80])
        expectEqual(widths.offsets, [0, 0])
        expectEqual(widths.size, 80)
        #expect(widths.fillCount == 0)
    }

    @Test
    func testConditionalFillParticipatesWhenItHasContent() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(ifContent: true)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300, intrinsicValues: [20, 0])

        expectEqual(widths.lengths, [150, 150])
        expectEqual(widths.offsets, [0, 150])
        expectEqual(widths.size, 300)
        #expect(widths.fillCount == 2)
    }

    @Test
    func testInactiveConditionalFillDoesNotDiluteOtherFillFraction() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(ifContent: true)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300, intrinsicValues: [0, 0])

        expectEqual(widths.lengths, [0, 300])
        expectEqual(widths.offsets, [0, 0])
        expectEqual(widths.size, 300)
        #expect(widths.fillCount == 1)
    }

    @Test
    func testZeroFractionFillIsLockedAtZero() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(0, min: 20)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 100)

        expectEqual(widths.lengths, [0, 100])
        expectEqual(widths.offsets, [0, 0])
        #expect(widths.fillCount == 1)
    }

    // MARK: - Gap correction

    @Test
    func testNewlyVisibleFillGapIsDeductedFromGrowth() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100), gap: 10),
                Track(.fill(), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 300)

        // The active fill reserves the preceding 10-point gap before
        // the complete sequential fill space is calculated.
        expectEqual(widths.lengths, [100, 190])
        expectEqual(widths.offsets, [0, 110])
        expectEqual(widths.size, 300)
    }

    @Test
    func testPositiveFillMinimumDoesNotAddAnotherGap() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100), gap: 10),
                Track(.fill(min: 50), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 300)

        // Fill minimums are absent from prepared sizing. The active fill
        // still reserves the preceding gap before fill allocation.
        expectEqual(widths.lengths, [100, 190])
        expectEqual(widths.offsets, [0, 110])
        expectEqual(widths.size, 300)
    }

    @Test
    func testZeroLengthElementBetweenVisibleElementsDoesNotAddGap() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100), gap: 10),
                Track(.fill(0), gap: 100),
                Track(.fixed(50), gap: 20)
            ],
            layout: .gaps
        )

        apply(widths, available: 500)

        expectEqual(widths.lengths, [100, 0, 50])
        expectEqual(widths.offsets, [0, 100, 110])
        expectEqual(widths.size, 160)
    }

    // MARK: - Stack fill

    @Test
    func testStackFillUsesFractionOfEntireAvailableSize() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(80)),
                Track(.fill(0.5))
            ],
            layout: .stack
        )

        apply(widths, available: 300)

        expectEqual(widths.lengths, [80, 150])
        expectEqual(widths.offsets, [0, 0])
        expectEqual(widths.size, 150)
    }

    @Test
    func testStackFillHonorsMinimumAndMaximum() {
        let minimumWidths = TrackLayout(
            tracks: [Track(.fill(0.1, min: 50, max: 200))],
            layout: .stack
        )
        apply(minimumWidths, available: 300)
        expectEqual(minimumWidths.lengths, [50])
        expectEqual(minimumWidths.offsets, [0])

        let maximumWidths = TrackLayout(
            tracks: [Track(.fill(1, min: 0, max: 120))],
            layout: .stack
        )
        apply(maximumWidths, available: 300)
        expectEqual(maximumWidths.lengths, [120])
        expectEqual(maximumWidths.offsets, [0])
    }

    // MARK: - Cache behavior

    @Test
    func testRepeatedBoundUsesCachedFillResult() {
        let widths = TrackLayout(
            tracks: [Track(.fill())],
            layout: .tight
        )
        var intrinsicCallCount = 0

        let intrinsic: (Int, Track, CGFloat) -> CGFloat = { _, _, _ in
            intrinsicCallCount += 1
            return 0
        }

        widths.apply(available: 200, intrinsic: intrinsic)
        let firstLengths = widths.lengths
        let firstOffsets = widths.offsets
        let firstSize = widths.size

        widths.apply(available: 200, intrinsic: intrinsic)

        expectEqual(widths.lengths, firstLengths)
        expectEqual(widths.offsets, firstOffsets)
        expectEqual(widths.size, firstSize)
        #expect(intrinsicCallCount == 0)
    }

    @Test
    func testChangedBoundRecalculatesFromBaseline() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 300)
        expectEqual(widths.lengths, [100, 200])

        apply(widths, available: 200)
        expectEqual(widths.lengths, [100, 100])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 200)
    }

    @Test
    func testUnboundedAfterBoundedRestoresBaseline() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(100)),
                Track(.fill(min: 25))
            ],
            layout: .tight
        )

        apply(widths, available: 300)
        expectEqual(widths.lengths, [100, 200])

        apply(widths, available: .unbounded)

        expectEqual(widths.lengths, [100, 0])
        expectEqual(widths.offsets, [0, 100])
        expectEqual(widths.size, 100)
    }

    // MARK: - Empty input

    @Test
    func testEmptyElementsRemainEmpty() {
        let widths = TrackLayout(tracks: [], layout: .tight)

        apply(widths, available: 100)

        #expect(widths.lengths.isEmpty)
        #expect(widths.offsets.isEmpty)
        expectEqual(widths.size, 0)
    }


    // MARK: - Explicit invalidation and factory input

    @Test
    func testInvalidateClearsPreparedAndResolvedState() {
        let widths = TrackLayout(
            tracks: [Track(.intrinsic())],
            layout: .tight
        )
        var intrinsicValue = CGFloat(10)
        var callCount = 0

        widths.apply { _, _, _ in
            callCount += 1
            return intrinsicValue
        }
        expectEqual(widths.lengths, [10])

        intrinsicValue = 20
        widths.invalidate()

        #expect(widths.lengths.isEmpty)
        #expect(widths.offsets.isEmpty)
        expectEqual(widths.size, 0)
        #expect(widths.fillCount == 0)

        widths.apply { _, _, _ in
            callCount += 1
            return intrinsicValue
        }

        expectEqual(widths.lengths, [20])
        expectEqual(widths.offsets, [0])
        expectEqual(widths.size, 20)
        #expect(callCount == 2)
    }

    @Test
    func testFactoryCreatesRequestedTracksOnlyOnce() {
        var requestedIndexes: [Int] = []
        let widths = TrackLayout(
            factory: { index in
                requestedIndexes.append(index)
                return Track(.fixed(CGFloat(index + 1) * 10))
            },
            count: 3,
            layout: .tight
        )

        apply(widths)

        #expect(requestedIndexes == [0, 1, 2])
        expectEqual(widths.lengths, [10, 20, 30])
        expectEqual(widths.offsets, [0, 10, 30])
        expectEqual(widths.size, 60)

        apply(widths)

        #expect(requestedIndexes == [0, 1, 2])
    }

    // MARK: - Input normalization

    @Test
    func testNegativeFixedAndIntrinsicLengthsClampToZero() {
        let widths = TrackLayout(
            tracks: [
                Track(.fixed(-10)),
                Track(.intrinsic())
            ],
            layout: .tight
        )

        widths.apply { index, _, _ in
            index == 1 ? -20 : 0
        }

        expectEqual(widths.lengths, [0, 0])
        expectEqual(widths.size, 0)
    }

    @Test
    func testNegativeAvailableSpaceAllocatesNoFill() {
        let widths = TrackLayout(
            tracks: [Track(.fill())],
            layout: .tight
        )

        apply(widths, available: -100)

        expectEqual(widths.lengths, [0])
        expectEqual(widths.offsets, [0])
        expectEqual(widths.size, 0)
    }

    @Test
    func testNonpositiveFillFractionAndMaximumLockAtZero() {
        let widths = TrackLayout(
            tracks: [
                Track(.fill(-0.5, min: 20)),
                Track(.fill(max: 0)),
                Track(.fill())
            ],
            layout: .tight
        )

        apply(widths, available: 90)

        expectEqual(widths.lengths, [0, 0, 90])
        #expect(widths.fillCount == 1)
    }
}
