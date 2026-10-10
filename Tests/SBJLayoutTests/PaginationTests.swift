import Foundation
import CoreGraphics
import Testing
@testable import SBJLayout

@Suite("Directive pagination")
struct PaginationTests {
    private final class Box: Renderable {
        let size: CGSize
        private(set) var drawn: [CGRect] = []

        init(height: CGFloat, width: CGFloat = 100) {
            size = CGSize(width: width, height: height)
        }

        func measure(bounds: CGSize) -> CGSize { size }
        func render(in allocated: CGRect, measured: CGSize, align: Alignment) {
            drawn.append(allocated)
        }
    }

    private func pagination(
        pages: Range<Int>? = nil,
        paging: ((Pagination) -> Void)? = nil
    ) -> Pagination {
        Pagination(
            layout: .init(pageSize: .custom(width: 100, height: 100), margins: .zero),
            pages: pages,
            paging: paging
        )
    }

    private func execute(
        _ pagination: Pagination,
        _ content: () -> Grid
    ) -> (Grid, CGSize) {
        RenderableEnvironment.withContext(pagination: pagination) {
            let grid = content()
            let measured = grid.measure(bounds: CGSize(width: 100, height: 1000))
            let allocated = CGRect(origin: .zero, size: measured)
            pagination.prepare(grid, in: allocated, measured: measured)
            grid.render(in: allocated, measured: measured, align: .leftTop)
            return (grid, measured)
        }
    }

    @Test("Prepare activates the initial page, including standalone renderables")
    func prepareActivatesFirstPage() {
        var opened: [Int] = []
        let planner = pagination(paging: { opened.append($0.currentPageIndex ?? -1) })
        RenderableEnvironment.withContext(pagination: planner) {
            let box = Box(height: 20)
            let measured = box.measure(bounds: CGSize(width: 100, height: 100))
            let allocated = CGRect(origin: .zero, size: measured)
            planner.prepare(box, in: allocated, measured: measured)
            #expect(opened == [0])
            #expect(planner.currentPageIndex == 0)
            box.render(in: allocated, measured: measured, align: .leftTop)
            #expect(opened == [0])
        }
    }

    @Test("Flow is the default and nested directives consume no Grid cells")
    func nestedFlow() {
        let first = Box(height: 60)
        let second = Box(height: 55)
        let third = Box(height: 40)
        let planner = pagination()
        let (grid, measured) = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup(sectionID: "spells") {
                    PaginationGroup(sectionID: "wizard") { first }
                    PaginationGroup(sectionID: "cleric") { second }
                    PaginationGroup(sectionID: "sorcerer") { third }
                }
            }
        }
        #expect(grid.layout.resolvedDefinition(for: measured).cells.count == 3)
        #expect(planner.pageCount == 2)
        #expect(first.drawn.first?.minY == 0)
        #expect(second.drawn.first?.minY == 0)
        #expect(third.drawn.first?.minY == 55)
        #expect(planner.positions["spells"]?.pageIndex == 0)
        #expect(planner.positions["cleric"]?.pageIndex == 1)
    }

    @Test("Coincident parent and child .page requirements open one page")
    func coincidentPage() {
        let earlier = Box(height: 40)
        let following = Box(height: 30)
        let planner = pagination()
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { earlier }
                PaginationGroup(behavior: .page) {
                    PaginationGroup(behavior: .page) { following }
                }
            }
        }
        #expect(planner.pageCount == 2)
        #expect(following.drawn.first?.minY == 0)
    }

    @Test("Keep With Above on a parent applies to its first unit only")
    func parentKeepWithFirstUnit() {
        let previous = Box(height: 60)
        let title = Box(height: 10)
        let first = Box(height: 20)
        let later = Box(height: 40)
        let planner = pagination()
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { previous }
                PaginationGroup(behavior: .keepWith) {
                    title
                    PaginationGroup { first }
                    PaginationGroup { later }
                }
            }
        }
        #expect(planner.pageCount == 2)
        #expect(previous.drawn.first?.minY == 0)
        #expect(title.drawn.first?.minY == 60)
        #expect(first.drawn.first?.minY == 70)
        #expect(later.drawn.first?.minY == 0)
    }

    @Test("Oversized indivisible content is never automatically split")
    func oversizedUnit() {
        let oversized = Box(height: 150)
        let next = Box(height: 30)
        let planner = pagination()
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { oversized }
                PaginationGroup { next }
            }
        }
        #expect(planner.pageCount == 2)
        #expect(oversized.drawn.count == 1)
        #expect(oversized.drawn.first?.height == 150)
        #expect(next.drawn.first?.minY == 0)
    }

    @Test("Absent directives never authorize a break")
    func ordinaryContentDoesNotSplit() {
        let a = Box(height: 75)
        let b = Box(height: 75)
        let planner = pagination()
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                a
                b
            }
        }
        #expect(planner.pageCount == 1)
        #expect(a.drawn.count == 1 && b.drawn.count == 1)
    }

    @Test("Only selected source pages are rendered")
    func selectedPages() {
        let a = Box(height: 60)
        let b = Box(height: 55)
        let c = Box(height: 40)
        var visited: [Int] = []
        let planner = pagination(pages: 1..<2) { visited.append($0.currentPageIndex!) }
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { a }
                PaginationGroup { b }
                PaginationGroup { c }
            }
        }
        #expect(planner.pageCount == 2)
        #expect(visited == [1])
        #expect(a.drawn.isEmpty)
        #expect(b.drawn.count == 1 && c.drawn.count == 1)
    }

    @Test("First and later pages respect the reserved content origin")
    func contentInsets() {
        let a = Box(height: 50)
        let b = Box(height: 50)
        let planner = Pagination(
            layout: .init(pageSize: .custom(width: 100, height: 100), margins: .zero),
            insets: .init(top: 20)
        )
        _ = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { a }
                PaginationGroup { b }
            }
        }
        #expect(planner.pageCount == 2)
        #expect(a.drawn.first?.minY == 20)
        #expect(b.drawn.first?.minY == 20)
    }

    @Test("Grid track drawing callbacks are paginated, not duplicated")
    func paginatedTracks() {
        let a = Box(height: 60)
        let b = Box(height: 55)
        var columns: [CGRect] = []
        let planner = pagination { current in
            for (rect, draw) in current.tracksForCurrentPage { draw(rect) }
        }
        _ = execute(planner) {
            Grid(
                vertFlow: .init(.fixed(100)),
                rows: .init(gap: 0),
                cells: {
                    PaginationGroup { a }
                    PaginationGroup { b }
                },
                colRender: { columns.append($0.rect) }
            )
        }
        #expect(planner.pageCount == 2)
        #expect(columns.count == 2)
    }

    @Test("An empty group does not introduce a new page or cell")
    func emptyGroup() {
        let a = Box(height: 60)
        let b = Box(height: 30)
        let planner = pagination()
        let (grid, measured) = execute(planner) {
            Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { a }
                PaginationGroup(behavior: .page) { }
                PaginationGroup { b }
            }
        }
        #expect(grid.layout.resolvedDefinition(for: measured).cells.count == 2)
        #expect(planner.pageCount == 1)
    }

    @Test("A vertical Panel forwards nested boundaries and page decorations")
    func panelForwarding() {
        let a = Box(height: 70)
        let b = Box(height: 60)
        var decoratedPages: [Int] = []
        let planner = pagination { current in
            if !current.decorationsForCurrentPage.isEmpty {
                decoratedPages.append(current.currentPageIndex!)
            }
        }
        RenderableEnvironment.withContext(pagination: planner) {
            let panel = Panel(background: JCSRect()) {
                Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                    PaginationGroup { a }
                    PaginationGroup { b }
                }
            }
            let measured = panel.measure(bounds: CGSize(width: 100, height: 1000))
            let frame = CGRect(origin: .zero, size: measured)
            planner.prepare(panel, in: frame, measured: measured)
            panel.render(in: frame, measured: measured, align: .leftTop)
        }
        #expect(planner.pageCount == 2)
        #expect(decoratedPages == [0, 1])
        #expect(a.drawn.first?.minY == 0)
        #expect(b.drawn.first?.minY == 0)
    }

    @Test("Directives on different cells in the same physical row cannot split that row")
    func horizontalRowIntegrity() {
        let a = Box(height: 60, width: 50)
        let b = Box(height: 60, width: 50)
        let planner = pagination()
        _ = execute(planner) {
            Grid(
                cols: .init([.init(.fixed(50)), .init(.fixed(50))]),
                rows: .init(gap: 0)
            ) {
                PaginationGroup { a }
                PaginationGroup { b }
            }
        }
        #expect(planner.pageCount == 1)
        #expect(a.drawn.count == 1 && b.drawn.count == 1)
    }

    @Test("Planning the same measured layout again produces the same assignments")
    func repeatedPlanning() {
        let a = Box(height: 60)
        let b = Box(height: 55)
        let planner = pagination()
        RenderableEnvironment.withContext(pagination: planner) {
            let grid = Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
                PaginationGroup { a }
                PaginationGroup { b }
            }
            for _ in 0..<2 {
                let measured = grid.measure(bounds: CGSize(width: 100, height: 1000))
                let frame = CGRect(origin: .zero, size: measured)
                planner.prepare(grid, in: frame, measured: measured)
                #expect(planner.pageCount == 2)
            }
        }
    }
}

#if canImport(PDFKit) && !os(watchOS)
import PDFKit

@Suite("Directive pagination PDF integration")
struct DirectivePaginationPDFTests {
    private struct PDFBox: Renderable {
        let height: CGFloat
        func measure(bounds: CGSize) -> CGSize { CGSize(width: 100, height: height) }
        func render(in allocated: CGRect, measured: CGSize, align: Alignment) {}
    }

    @Test("The generated PDF has the planned pages and section positions")
    func actualPDF() {
        let grid = Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
            PaginationGroup(sectionID: "first") { PDFBox(height: 60) }
            PaginationGroup(sectionID: "second") { PDFBox(height: 55) }
            PaginationGroup(sectionID: "third") { PDFBox(height: 40) }
        }
        let generator = PDFGenerator(pageLayout: .init(
            pageSize: .custom(width: 100, height: 100), margins: .zero
        ))
        let result = generator.form(grid)
        #expect(result.document?.pageCount == 2)
        #expect(result.positions["first"]?.pageIndex == 0)
        #expect(result.positions["second"]?.pageIndex == 1)
        #expect(result.positions["third"]?.pageIndex == 1)
    }

    @Test("A selected page range exports only the requested physical page")
    func selectedPDFPages() {
        let grid = Grid(vertFlow: .init(.fixed(100)), rows: .init(gap: 0)) {
            PaginationGroup { PDFBox(height: 60) }
            PaginationGroup { PDFBox(height: 55) }
        }
        let generator = PDFGenerator(pageLayout: .init(
            pageSize: .custom(width: 100, height: 100), margins: .zero
        ))
        let result = generator.form(grid, pages: 1..<2)
        #expect(result.document?.pageCount == 1)
    }
}
#endif
