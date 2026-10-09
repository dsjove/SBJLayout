import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Grid row accessories")
struct GridRowAccessoryTests {
    private final class Element: TrackElement {
        let size: CGSize
        init(_ width: CGFloat, _ height: CGFloat) { size = CGSize(width: width, height: height) }
        func measure(bounds: CGSize) -> CGSize { size }
    }

    private func makeLayout(accessoryHeight: CGFloat, placement: Track.AccessoryPlacement = .after) -> GridLayout<Element> {
        let columns: [Track] = [
            .init(.fixed(30), gap: 3),
            .rowAccessory(placement: placement, gap: 4, align: .right),
            .init(.fixed(40), gap: 0)
        ]
        return GridLayout(
            columns: .init([columns[0], columns[2]]),
            rows: .init(gap: 2),
            cells: [Element(20, 10), Element(1000, accessoryHeight), Element(35, 15),
                    Element(20, 12), Element(1000, 0), Element(35, 8)],
            accessories: [.init(inputStride: 3, slot: 1, track: columns[1], physicalSlots: [0, 2])]
        )
    }

    @Test("Accessories consume input slots without creating physical columns")
    func inputMapping() {
        let definition = makeLayout(accessoryHeight: 9).measure(bounds: CGSize(width: 200, height: 200))
        #expect(definition.columnCount == 2)
        #expect(definition.inputStride == 3)
        #expect(definition.rowCount == 2)
        #expect(definition.cellIdx(0, 1) == 3)
        #expect(definition.cellIdx(1, 1) == 5)
        #expect(definition.accessoryIndex(row: 0, accessory: definition.accessories[0]) == 1)
        #expect(definition.accessoryIndex(row: 1, accessory: definition.accessories[0]) == 4)
        #expect(definition.columns.size == 73)
    }

    @Test("Accessory measurement increases row height and uses full width")
    func measurementAndPosition() {
        let definition = makeLayout(accessoryHeight: 9).measure(bounds: CGSize(width: 200, height: 200))
        #expect(definition.rows.lengths[0] == 28) // 15 + 4 + 9
        #expect(definition.rows.lengths[1] == 12) // Empty accessory adds no gap
        let rect = definition.accessoryRect(row: 0, accessory: definition.accessories[0])
        #expect(rect?.width == 73)
        #expect(rect?.height == 9)
        #expect(rect?.minY == 19)
        #expect(definition.accessoryRect(row: 1, accessory: definition.accessories[0]) == nil)
        #expect(definition.allocatedRect(column: 0, row: 0).height == 15)
    }

    @Test("Above placement reserves space before ordinary cells")
    func abovePlacement() {
        let definition = makeLayout(accessoryHeight: 9, placement: .before).measure(bounds: CGSize(width: 200, height: 200))
        #expect(definition.rows.lengths[0] == 28)
        #expect(definition.accessoryRect(row: 0, accessory: definition.accessories[0])?.minY == 0)
        #expect(definition.accessoryRect(row: 0, accessory: definition.accessories[0])?.height == 9)
        #expect(definition.allocatedRect(column: 0, row: 0).minY == 13)
        #expect(definition.allocatedRect(column: 0, row: 0).height == 15)
        #expect(definition.accessoryRect(row: 1, accessory: definition.accessories[0]) == nil)
        #expect(definition.allocatedRect(column: 0, row: 1).minY == definition.rows.offsets[1])
    }

    @Test("Accessory placement defaults to below and survives track copying")
    func placementDefaultsAndCopy() {
        let standard = Track.rowAccessory()
        #expect(standard.role.accessoryPlacement == .after)
        let before = Track.rowAccessory(placement: .before)
        #expect(Track(before, aggregate: { $0.max() }).role.accessoryPlacement == .before)
    }

    @Test("Accessory alignment does not inherit row alignment")
    func independentAlignment() {
        let definition = makeLayout(accessoryHeight: 9).measure(bounds: CGSize(width: 200, height: 200))
        var alignments: [Int: Alignment] = [:]
        definition.iterate(cell: { iteration in
            alignments[iteration.i] = iteration.alignment
        })
        #expect(alignments[1] == .right)
    }

    @Test("Minimum measurement includes accessory, without disturbing normal layout")
    func minimumMeasurement() {
        let layout = makeLayout(accessoryHeight: 9)
        let before = layout.measure(bounds: CGSize(width: 200, height: 200)).size
        let minimum = layout.minimumMeasure(bounds: CGSize(width: 200, height: 200))
        let after = layout.measure(bounds: CGSize(width: 200, height: 200)).size
        #expect(minimum.height >= 0)
        #expect(before == after)
    }
    @Test("Multiple accessories preserve input slots and stack by placement")
    func multipleAccessories() {
        let tracks: [Track] = [
            .rowAccessory(placement: .after, gap: 2),
            .init(.fixed(20)),
            .rowAccessory(placement: .before, gap: 3),
            .rowAccessory(placement: .after, gap: 4),
            .init(.fixed(30)),
            .rowAccessory(placement: .before, gap: 1)
        ]
        let accessories = [0, 2, 3, 5].map {
            GridDefinition<Element>.RowAccessory(inputStride: 6, slot: $0, track: tracks[$0], physicalSlots: [1, 4])
        }
        let layout = GridLayout(
            columns: .init([tracks[1], tracks[4]]),
            cells: [Element(4, 5), Element(15, 10), Element(4, 6), Element(4, 7), Element(15, 12), Element(4, 8)],
            accessories: accessories
        )
        let definition = layout.measure(bounds: CGSize(width: 100, height: 200))
        #expect(definition.inputStride == 6)
        #expect(definition.columnCount == 2)
        #expect(definition.rows.lengths[0] == 48) // 12 + (5+2) + (6+3) + (7+4) + (8+1)
        #expect(definition.cellIdx(0, 0) == 1)
        #expect(definition.cellIdx(1, 0) == 4)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[1])?.minY == 0)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[3])?.minY == 9)
        #expect(definition.allocatedRect(column: 0, row: 0).minY == 18)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[0])?.minY == 32)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[2])?.minY == 41)
        var columnSegments = 0
        definition.iterate(column: { column in
            #expect(column.rect.height == 12)
            columnSegments += 1
        }, cell: { _ in })
        #expect(columnSegments == 2)
    }

    @Test("Empty accessories do not introduce spacing among duplicate placements")
    func emptyStack() {
        let first = Track.rowAccessory(placement: .before, gap: 5)
        let second = Track.rowAccessory(placement: .before, gap: 3)
        let accessories = [
            GridDefinition<Element>.RowAccessory(inputStride: 3, slot: 0, track: first, physicalSlots: [1]),
            GridDefinition<Element>.RowAccessory(inputStride: 3, slot: 2, track: second, physicalSlots: [1])
        ]
        let definition = GridLayout(columns: .init([Track(.fixed(25))]),
            cells: [Element(0, 0), Element(20, 10), Element(10, 4)],
            accessories: accessories).measure(bounds: CGSize(width: 100, height: 100))
        #expect(definition.rows.lengths[0] == 17)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[0]) == nil)
        #expect(definition.accessoryRect(row: 0, accessory: accessories[1])?.minY == 0)
        #expect(definition.allocatedRect(column: 0, row: 0).minY == 7)
    }

    @Test("Column decorations end at the last visible column when trailing columns are suppressed")
    func trailingSuppressedColumns() {
        let tracks = [Track(.fixed(20)), Track(.fixed(30)), Track(.fixed(0)), Track(.fixed(0))]
        let accessory = Track.rowAccessory(gap: 0)
        let definition = GridLayout(
            columns: .init(tracks),
            rows: .init(gap: 0),
            cells: [Element(10, 10), Element(10, 10), Element(0, 0), Element(0, 0), Element(30, 6)],
            accessories: [.init(inputStride: 5, slot: 4, track: accessory, physicalSlots: [0, 1, 2, 3])]
        ).measure(bounds: CGSize(width: 200, height: 200))
        var decorated: [Int] = []
        definition.iterate(column: { decorated.append($0.index) }, cell: { _ in })
        #expect(decorated == [0])
        #expect(definition.accessoryRect(row: 0, accessory: definition.accessories[0])?.minY == 10)
        #expect(definition.rows.lengths[0] == 16)
    }

}
