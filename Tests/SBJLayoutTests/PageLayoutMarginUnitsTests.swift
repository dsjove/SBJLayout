import Testing
@testable import SBJLayout

@Test func marginUnitsAndPDFGeometry() {
    var layout = PageLayout()
    #expect(abs(layout.left.value - 0.25) < 0.00001)
    #expect(abs(layout.marginsInPDFPoints.left - 18) < 0.00001)
    layout.pageSize = .a4
    #expect(layout.left.unit == .millimeter)
    #expect(abs(layout.left.value - 6.35) < 0.00001)
    #expect(abs(layout.marginsInPDFPoints.left - 18) < 0.00001)
    layout.pageSize = .letter
    #expect(layout.left.unit == .inch)
    #expect(abs(layout.left.value - 0.25) < 0.00001)
}

@Test func sameUnitSizeChangePreservesStoredMargins() {
    var layout = PageLayout(pageSize: .letter, top: .init(0.5, unit: .inch), left: .init(0.8, unit: .inch))
    layout.pageSize = .legal
    #expect(layout.left.value == 0.8)
    #expect(layout.top.value == 0.5)
}

@Test func eachMarginCanUseItsOwnUnit() {
    let layout = PageLayout(
        pageSize: .letter,
        top: .init(12.7, unit: .millimeter),
        bottom: .init(0.5, unit: .inch),
        left: .init(36, unit: .point),
        right: .init(1, unit: .centimeter)
    )
    let pdf = layout.marginsInPDFPoints
    #expect(abs(pdf.top - 36) < 0.00001)
    #expect(abs(pdf.bottom - 36) < 0.00001)
    #expect(abs(pdf.left - 36) < 0.00001)
    #expect(abs(pdf.right - (72.0 / 2.54)) < 0.00001)
}
