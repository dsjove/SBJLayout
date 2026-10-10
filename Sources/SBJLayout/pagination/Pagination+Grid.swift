import Foundation
import CoreGraphics

// Grid reports resolved layout geometry. The pagination coordinator owns
// traversal order, page placement, and whether a cell is rendered.
extension Pagination {
    func collectEvents(
        from grid: Grid, in allocated: CGRect, measured: CGSize,
        align: Alignment, into events: inout [PaginationEvent]
    ) {
        let definition = grid.layout.resolvedDefinition(for: measured)
        let positioned = align.apply(size: definition.size, in: allocated)
        var result: [PaginationEvent] = []
        var seen = Set<Int>()
        var cells: [Grid.CellIteration] = []
        definition.iterate(allocated: positioned) { cell in
            if cell.cell != nil, seen.insert(cell.i).inserted { cells.append(cell) }
        }
        // Builder order, not visual column iteration, determines directive order.
        cells.sort { $0.i < $1.i }
        var nextBoundary = 0
        for cell in cells {
            while nextBoundary <= cell.i && nextBoundary < grid.paginationContent.boundaries.count {
                result.append(contentsOf: grid.paginationContent.boundaries[nextBoundary])
                nextBoundary += 1
            }
            guard let item = cell.cell?.element else { continue }
            if let nested = item as? any PaginationTraversable, nested.hasPaginationGroups {
                nested.collectPaginationEvents(
                    in: cell.rect, measured: cell.content ?? cell.rect.size,
                    align: cell.alignment, into: &result)
            } else {
                result.append(.item(PaginationItemID(grid: grid.paginationID, index: cell.i), cell.rect))
            }
        }
        while nextBoundary < grid.paginationContent.boundaries.count {
            result.append(contentsOf: grid.paginationContent.boundaries[nextBoundary])
            nextBoundary += 1
        }
        // During paginated rendering, draw row/column decorations in the
        // page-opening phase, before the page's cell content. A track that
        // spans pages is clipped and rendered once on each affected page.
        let itemFrames: [(PaginationItemID, CGRect)] = result.compactMap {
            if case .item(let id, let frame) = $0 { return (id, frame) }
            return nil
        }
        if grid.hasPaginationGroups && (grid.render.column != nil || grid.render.row != nil) {
            var trackEvents: [PaginationEvent] = []
            definition.iterate(
                allocated: positioned,
                column: { iteration in
                    guard let callback = grid.render.column else { return }
                    let ids = itemFrames.filter { $0.1.intersects(iteration.rect) }.map(\.0)
                    trackEvents.append(.trackDecoration(UUID(), iteration.rect, ids) { frame in
                        callback(.init(
                            definition: iteration.definition,
                            track: iteration.track,
                            index: iteration.index,
                            rect: frame
                        ))
                    })
                },
                row: { iteration in
                    guard let callback = grid.render.row else { return }
                    let ids = itemFrames.filter { $0.1.intersects(iteration.rect) }.map(\.0)
                    trackEvents.append(.trackDecoration(UUID(), iteration.rect, ids) { frame in
                        callback(.init(
                            definition: iteration.definition,
                            track: iteration.track,
                            index: iteration.index,
                            rect: frame
                        ))
                    })
                },
                cell: { _ in }
            )
            // Register visual decorations outside pagination scope events.
            events.append(contentsOf: trackEvents)
        }
        events.append(contentsOf: result)
    }

    func renderGrid(
        _ grid: Grid, definition: Grid.Definition, positioned: CGRect
    ) {
        let pagination = self
        let isPaginated = pagination.isPrepared && grid.hasPaginationGroups
        if pagination.isPrepared && !grid.hasPaginationGroups &&
           pagination.currentPageIndex != nil && !pagination.isRenderingPage {
            return // Root/atomic nonpaginated Grid on an excluded source page.
        }

        func renderCell(_ cell: Grid.CellIteration) {
            guard let item = cell.cell?.element else { return }
            if let nested = item as? any PaginationTraversable, nested.hasPaginationGroups {
                grid.render.cell(cell)
            } else {
                guard let moved = pagination.placement(
                    of: PaginationItemID(grid: grid.paginationID, index: cell.i),
                    default: cell.rect
                ) else { return }
                grid.render.cell(.init(
                    definition: cell.definition, cell: cell.cell,
                    c: cell.c, r: cell.r, i: cell.i,
                    rect: moved, content: cell.content,
                    alignment: cell.alignment
                ))
            }
        }

        if isPaginated {
            // Pagination planning and rendering must traverse cells in the
            // same logical builder order, even with Grid row accessories or
            // wrapped tracks. Row and column drawing is scheduled per page.
            var drawn = Set<Int>()
            var cells: [Grid.CellIteration] = []
            definition.iterate(allocated: positioned) { cell in
                if cell.cell != nil, drawn.insert(cell.i).inserted {
                    cells.append(cell)
                }
            }
            cells.sort { $0.i < $1.i }
            for cell in cells { renderCell(cell) }
        } else {
            definition.iterate(
                allocated: positioned,
                column: grid.render.column,
                row: grid.render.row,
                cell: renderCell
            )
        }
    }
}
