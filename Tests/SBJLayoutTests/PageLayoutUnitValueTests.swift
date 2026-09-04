import Testing
import SBJFoundation
@testable import SBJLayout

struct PageLayoutUnitValueTests {
    @Test func pdfPointMarginsUseSharedLengthConversion() {
        let margin = UnitValue<LengthUnit>(72, unit: .point)
        #expect(abs(margin.converted(to: .inch).value - 1) < 0.000_001)
        #expect(abs(margin.converted(to: .millimeter).value - 25.4) < 0.000_001)
    }
}

extension PageLayoutUnitValueTests {
    @Test func pageLayoutExposesPhysicalDimensionsAsUnitValues() {
        let page = PageLayout(pageSize: .letter)
        #expect(abs(page.pageWidth.converted(to: .inch).value - 8.5) < 0.000_001)
        #expect(abs(page.pageHeight.converted(to: .inch).value - 11) < 0.000_001)
    }
}
