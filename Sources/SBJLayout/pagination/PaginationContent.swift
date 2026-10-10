import Foundation
import CoreGraphics

/// Identity for one occurrence of a content cell in a Grid. A renderable may
/// occur in multiple cells, so its object identity cannot identify placement.
struct PaginationItemID: Hashable {
    let grid: UUID
    let index: Int
}

enum PaginationEvent {
    case begin(PaginationGroup)
    case end(UUID)
    case item(PaginationItemID, CGRect)
    case beginDecoration(UUID, JCSRect, CGRect)
    case endDecoration(UUID)
    case trackDecoration(UUID, CGRect, [PaginationItemID], (CGRect) -> Void)
}

/// Layout containers report the resolved geometry of their drawable children.
/// This does not permit arbitrary splitting: groups in the event stream are
/// the sole source of legal page-break boundaries.
protocol PaginationTraversable {
    var hasPaginationGroups: Bool { get }
    func collectPaginationEvents(
        in allocated: CGRect,
        measured: CGSize,
        align: Alignment,
        into events: inout [PaginationEvent]
    )
}

struct FlattenedPaginationContent {
    let cells: [any Renderable]
    /// Scope boundaries at each cell index, including a sentinel after the last.
    let boundaries: [[PaginationEvent]]

    init(_ content: Renderables) {
        var cells: [any Renderable] = []
        var boundaries: [[PaginationEvent]] = [[]]

        func flatten(_ nodes: [Renderables.Node]) {
            for node in nodes {
                switch node {
                case .content(let item):
                    cells.append(item)
                    boundaries.append([])
                case .group(let group):
                    boundaries[cells.count].append(.begin(group))
                    flatten(group.content.nodes)
                    boundaries[cells.count].append(.end(group.id))
                }
            }
        }
        flatten(content.nodes)
        self.cells = cells
        self.boundaries = boundaries
    }

    var hasGroups: Bool {
        boundaries.contains { !$0.isEmpty }
    }
}
