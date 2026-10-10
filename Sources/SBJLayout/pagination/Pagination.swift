import Foundation
import CoreGraphics

public struct PaginationPosition: Equatable, Sendable {
    public let pageIndex: Int
    public let frame: CGRect
    public let pageRect: CGRect

    public init(pageIndex: Int, frame: CGRect, pageRect: CGRect) {
        self.pageIndex = pageIndex
        self.frame = frame
        self.pageRect = pageRect
    }
}

/// A document-level pagination planner and rendering coordinator.
///
/// Measurement produces an ordinary unpaginated layout. `prepare` then
/// traverses the layout, takes breaks only at group entry directives and
/// assigns page/coordinate translations to the actual drawable cells.
/// Neither a parent nor a child group can independently advance a page.
public final class Pagination {
    struct Placement {
        let page: Int
        let frame: CGRect
    }

    private struct Item {
        let id: PaginationItemID
        let frame: CGRect
        var sectionIDs: [String]
    }

    private struct Segment {
        var behavior: PaginationBehavior
        var items: [Item]
        var minY: CGFloat { items.map(\.frame.minY).min() ?? 0 }
        var maxY: CGFloat { items.map(\.frame.maxY).max() ?? 0 }
    }

    private final class DecorationScope {
        let id: UUID
        let background: JCSRect
        let frame: CGRect
        var items: [PaginationItemID] = []

        init(id: UUID, background: JCSRect, frame: CGRect) {
            self.id = id
            self.background = background
            self.frame = frame
        }
    }

    private struct Unit {
        var segments: [Segment]
        var forcePage: Bool
        var minY: CGFloat { segments.map(\.minY).min() ?? 0 }
        var maxY: CGFloat { segments.map(\.maxY).max() ?? 0 }
    }

    private final class Scope {
        let group: PaginationGroup
        var behavior: PaginationBehavior
        var started = false
        var childStarted = false

        init(_ group: PaginationGroup, behavior: PaginationBehavior) {
            self.group = group
            self.behavior = behavior
        }
    }

    public let layout: PageLayout
    public let estimatedPageCountMax: Int?
    public let pagesToRender: Range<Int>?
    public let paging: ((Pagination) -> Void)?
    public var pageRect: CGRect { layout.pageRect }
    public var printableRect: CGRect { layout.printableRect }
    public let contentRect: CGRect

    public private(set) var pageCount: Int = 1
    public var pageNumber: Int { pageCount }
    public var currentPageIndex: Int? { sourcePageIndex >= 0 ? sourcePageIndex : nil }
    public var currentPageNumber: Int { max(1, sourcePageIndex + 1) }
    public var currentPageContext: PageContext? {
        guard let currentPageIndex else { return nil }
        return .init(index: currentPageIndex, number: currentPageIndex + 1, count: pageCount)
    }
    public private(set) var positions: [String: PaginationPosition] = [:]

    private var assignments: [PaginationItemID: Placement] = [:]
    private var pageDecorations: [Int: [(JCSRect, CGRect)]] = [:]
    private var pageTrackDecorations: [Int: [(CGRect, (CGRect) -> Void)]] = [:]
    var tracksForCurrentPage: [(CGRect, (CGRect) -> Void)] {
        pageTrackDecorations[sourcePageIndex] ?? []
    }
    var isPrepared: Bool { prepared }
    var decorationsForCurrentPage: [(JCSRect, CGRect)] {
        pageDecorations[sourcePageIndex] ?? []
    }
    private var positionAnchors: [PaginationItemID: [String]] = [:]
    private var prepared = false
    private var sourcePageIndex = -1
    private var outputPageIndex = -1
    private(set) var isRenderingPage = false

    public init(
        layout: PageLayout = .init(),
        insets: Insets = .zero,
        estimatedPageCountMax: Int? = nil,
        pages: Range<Int>? = nil,
        paging: ((Pagination) -> Void)? = nil
    ) {
        self.layout = layout
        self.estimatedPageCountMax = estimatedPageCountMax
        self.pagesToRender = pages
        self.paging = paging
        self.contentRect = insets.apply(to: layout.printableRect)
    }

    /// Establish all source-page assignments before drawing begins, allowing
    /// page numbers and page-range filtering to share a single accurate plan.
    func prepare(
        _ content: any Renderable,
        in allocated: CGRect,
        measured: CGSize,
        align: Alignment = .leftTop
    ) {
        assignments.removeAll(keepingCapacity: true)
        pageDecorations.removeAll(keepingCapacity: true)
        pageTrackDecorations.removeAll(keepingCapacity: true)
        positionAnchors.removeAll(keepingCapacity: true)
        positions.removeAll(keepingCapacity: true)
        sourcePageIndex = -1
        outputPageIndex = -1
        isRenderingPage = false

        var events: [PaginationEvent] = []
        if let traversable = content as? any PaginationTraversable {
            traversable.collectPaginationEvents(
                in: allocated, measured: measured, align: align, into: &events)
        }
        plan(events)
        prepared = true
        activate(page: 0)
    }

    private func plan(_ events: [PaginationEvent]) {
        var scopes: [Scope] = []
        var segments: [Segment] = []
        var activeDecorations: [DecorationScope] = []
        var allDecorations: [DecorationScope] = []
        var originalFrames: [PaginationItemID: CGRect] = [:]
        var trackDecorations: [(CGRect, [PaginationItemID], (CGRect) -> Void)] = []

        for event in events {
            switch event {
            case .trackDecoration(_, let frame, let ids, let draw):
                trackDecorations.append((frame, ids, draw))

            case .beginDecoration(let id, let background, let frame):
                let decoration = DecorationScope(id: id, background: background, frame: frame)
                activeDecorations.append(decoration)
                allDecorations.append(decoration)

            case .endDecoration(let id):
                precondition(activeDecorations.last?.id == id,
                             "Malformed pagination decoration nesting")
                activeDecorations.removeLast()

            case .begin(let group):
                var effective = group.behavior
                if let parent = scopes.last {
                    // The first child follows a parent's ordinary prefix.
                    // Keep its entry with that prefix unless explicitly .page.
                    if parent.started && !parent.childStarted && effective == .flow {
                        effective = .keepWith
                    }
                    parent.childStarted = true
                }
                scopes.append(Scope(group, behavior: effective))

            case .end(let groupID):
                // Empty groups are harmless: no segment was ever started.
                precondition(scopes.last?.group.id == groupID,
                             "Malformed pagination directive nesting")
                scopes.removeLast()

            case .item(let id, let frame):
                originalFrames[id] = frame
                for decoration in activeDecorations { decoration.items.append(id) }
                var entry: PaginationBehavior?
                var sectionIDs: [String] = []
                for scope in scopes where !scope.started {
                    scope.started = true
                    if let sectionID = scope.group.sectionID {
                        sectionIDs.append(sectionID)
                    }
                    switch (entry, scope.behavior) {
                    case (_, .page): entry = .page
                    case (.page, _): break
                    case (_, .keepWith): entry = .keepWith
                    case (nil, .flow): entry = .flow
                    default: break
                    }
                }

                let item = Item(id: id, frame: frame, sectionIDs: sectionIDs)
                if let entry {
                    segments.append(Segment(behavior: entry, items: [item]))
                } else if segments.isEmpty {
                    segments.append(Segment(behavior: .flow, items: [item]))
                } else {
                    segments[segments.count - 1].items.append(item)
                }
            }
        }
        precondition(scopes.isEmpty, "Unbalanced pagination directives")
        precondition(activeDecorations.isEmpty, "Unbalanced pagination decorations")

        // A boundary inside a horizontal Grid row is not a legal page split.
        // For .flow/.keepWith we safely merge instead of splitting siblings.
        // An explicit .page there is a layout conflict and should be fixed by
        // placing the group at a legal row boundary in the containing Grid.
        var legal: [Segment] = []
        for segment in segments {
            if let previous = legal.last, segment.minY < previous.maxY - 0.01 {
                precondition(segment.behavior != .page,
                    "PaginationGroup(.page) begins inside a Grid row. Move the group to a row boundary.")
                legal[legal.count - 1].items.append(contentsOf: segment.items)
            } else {
                legal.append(segment)
            }
        }

        // Keep With Above joins adjacent logical segments into one fit unit.
        // If a keep chain itself exceeds a page, it remains indivisible.
        var units: [Unit] = []
        for segment in legal {
            if segment.behavior == .keepWith, !units.isEmpty {
                units[units.count - 1].segments.append(segment)
            } else {
                units.append(Unit(segments: [segment], forcePage: segment.behavior == .page))
            }
        }

        var page = 0
        var offsetY: CGFloat = contentRect.minY - printableRect.minY
        var previousVirtualEnd: CGFloat?
        let pageTop = contentRect.minY
        let pageBottom = contentRect.maxY

        for (index, unit) in units.enumerated() {
            let needsBreak = index > 0 && (
                unit.forcePage || unit.maxY + offsetY > pageBottom + 0.01
            )
            if needsBreak {
                page += 1
                offsetY = pageTop - unit.minY
            } else if previousVirtualEnd == nil {
                // Preserve the layout's leading space while translating the
                // printable origin beneath the page header/content insets.
                offsetY = contentRect.minY - printableRect.minY
            }

            for segment in unit.segments {
                for item in segment.items {
                    assignments[item.id] = Placement(
                        page: page,
                        frame: item.frame.offsetBy(
                            dx: contentRect.minX - printableRect.minX,
                            dy: offsetY
                        )
                    )
                    if !item.sectionIDs.isEmpty {
                        positionAnchors[item.id, default: []].append(contentsOf: item.sectionIDs)
                    }
                }
            }
            previousVirtualEnd = unit.maxY
        }
        pageCount = max(1, page + 1)

        // Decorations are emitted as page backgrounds, before any cell on
        // that page. A wrapper is clipped to the current physical page and
        // translated with the content fragment assigned to that page.
        for decoration in allDecorations {
            var pageOffsets: [Int: (CGFloat, CGFloat)] = [:]
            for id in decoration.items {
                guard let placed = assignments[id], let original = originalFrames[id] else { continue }
                if pageOffsets[placed.page] == nil {
                    pageOffsets[placed.page] = (
                        placed.frame.minX - original.minX,
                        placed.frame.minY - original.minY
                    )
                }
            }
            for page in pageOffsets.keys.sorted() {
                guard let (dx, dy) = pageOffsets[page] else { continue }
                pageDecorations[page, default: []].append((
                    decoration.background,
                    decoration.frame.offsetBy(dx: dx, dy: dy)
                ))
            }
        }
        for (frame, ids, draw) in trackDecorations {
            var pageOffsets: [Int: (CGFloat, CGFloat)] = [:]
            for id in ids {
                guard let placed = assignments[id], let original = originalFrames[id] else { continue }
                if pageOffsets[placed.page] == nil {
                    pageOffsets[placed.page] = (
                        placed.frame.minX - original.minX,
                        placed.frame.minY - original.minY
                    )
                }
            }
            for page in pageOffsets.keys.sorted() {
                guard let (dx, dy) = pageOffsets[page] else { continue }
                pageTrackDecorations[page, default: []].append((
                    frame.offsetBy(dx: dx, dy: dy), draw
                ))
            }
        }
    }

    /// Lookup is side-effect free during measurement. During rendering it opens
    /// a physical PDF page at most once for each selected source page.
    func placement(of id: PaginationItemID, default virtual: CGRect) -> CGRect? {
        guard prepared else { return virtual }
        guard let placement = assignments[id] else { return virtual }
        activate(page: placement.page)
        guard isRenderingPage else { return nil }
        for sectionID in positionAnchors[id] ?? [] {
            positions[sectionID] = PaginationPosition(
                pageIndex: outputPageIndex,
                frame: placement.frame,
                pageRect: pageRect
            )
        }
        return placement.frame
    }

    private func activate(page: Int) {
        guard sourcePageIndex != page else { return }
        precondition(page >= sourcePageIndex, "Rendering order differs from pagination traversal")
        sourcePageIndex = page
        isRenderingPage = pagesToRender?.contains(page) ?? true
        if isRenderingPage {
            outputPageIndex += 1
            if let paging {
                paging(self)
            } else {
                // In a single CGContext (rather than PDFGenerator), preserve
                // the custom track drawing callbacks during pagination.
                for (frame, draw) in tracksForCurrentPage { draw(frame) }
            }
        }
    }
}
