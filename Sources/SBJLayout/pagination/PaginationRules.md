# Pagination rules

This is the normative behavior of SBJLayout's directive-based pagination system.

## Architecture

`PaginationGroup` is a **directive** within `RenderableBuilder`, **not** a `Renderable`, a Grid cell, or a layout container. It creates no Grid and does not measure, render, or re-origin its children. Its only attributes are an optional `sectionID`, a `PaginationBehavior`, and an ordered child builder result. The default behavior is `.flow`.

`RenderableBuilder` returns `Renderables`, preserving a hierarchy of ordinary content and group directives. `Renderables` is also a collection of the ordinary renderables, excluding all directives. Loops, optional branches, and arrays preserve source order and do not flatten away group boundaries.

`Grid` lays out **only** the ordinary renderables. Group boundaries are metadata at logical cell indices; nesting introduces no additional cells or duplicate measurements. `Panel` forwards pagination through a contained paginating Grid, accounting for content insets. An ordinary child without internal group boundaries is indivisible by default.

`Pagination` receives a pre-render traversal of the measured layout, resolves logical content units and their permissible boundaries, assigns them to source pages, and stores the final placements. The renderer uses those placements. There are **no** page advances or nested origin translations executed by `PaginationGroup` instances.

No content may be split at an undeclared boundary.

## Behaviors

- **`.flow`** (default) permits, but does not require, a break **before the group's first content**.
- **`.page`** requires a new page before the first content, except when the content already starts the first page or the same boundary already starts a new page.
- **`.keepWith`** means **Keep With Above**. The first logical unit of this group joins the immediately preceding unit when one exists and no `.page` contradicts it. It does **not** keep every descendant of the group together.
- An empty group makes no cell and introduces no page break.
- A `.keepWith` at the beginning of a document is equivalent to `.flow`.
- A `.page` requirement prevails when it conflicts with a `.keepWith` requirement at the same boundary.
- Consecutive `.keepWith` relationships form one page-fit unit. An oversized keep chain remains indivisible.

## Nested groups

The parent defines a scope and an entry boundary; the child may establish a separate **internal** boundary. A parent and child beginning at the same logical position produce **one** effective boundary, not two.

- A parent's entry behavior applies **once**, to the first nonempty unit of its content.
- A child's own behavior applies at the child's first content unit.
- A first child following ordinary prefix content is kept with that prefix if the child is `.flow`. Explicit `.page` on the child still forces a separate page.
- Ordinary content after a child, before another child, or at the end of the parent attaches to the preceding unit; no undeclared boundary is manufactured.
- Nested descendants are measured exactly once through the layout container, not again as independent parent and child blocks.
- The group hierarchy is never responsible for stacking page-origin offsets.

| Parent | Child | Effective behavior |
|---|---|---|
| `.flow` | `.flow` | Child may begin on next page if necessary |
| `.flow` | `.page` | Child requires one page transition |
| `.flow` | `.keepWith` | Child's first unit keeps with above |
| `.page` | `.flow` | Parent enters on a new page; later child may flow |
| `.page` | `.page` | Coincident requirements collapse; distinct later boundaries still require a page |
| `.page` | `.keepWith` | Parent page entry applies once; child's keep applies where compatible |
| `.keepWith` | `.flow` | Parent's first unit keeps with above; subsequent child can flow |
| `.keepWith` | `.page` | Explicit child page requirement wins on conflict |
| `.keepWith` | `.keepWith` | Adjacent keep relationships form a chain |

## Grid boundaries and wrapping

A directive's position is **logical content order**, never an X/Y offset supplied by the caller. During pre-render planning, Grid resolves the layout of real content cells and associates the logical boundaries with their actual measured rectangles.

A break that would divide a **physical Grid row** is not permitted. For `.flow` and `.keepWith` this boundary is merged with the preceding unit (not interpreted as permission to split the row). An explicit `.page` inside a row is a contradictory layout request and raises a precondition failure, rather than producing an incorrect PDF.

A Grid wrapping its tracks **does not currently add implicit page-break permission**. The existing Grid TODO describes a future addition: generate implicit `.flow` boundaries only at confirmed, complete wrapped-row boundaries. This should use the same internal logical-boundary model as explicit groups; no public coordinate-based API or `PageSplitHint` is required.

Grid's custom row and column drawing callbacks are page-aware when the Grid contains paginating content: a track crossing pages is scheduled once on each affected page and clipped to its printable content area. Custom cell render callbacks receive the page-adjusted `CellIteration.rect`; a callback wrapping nested paginating content must still render that nested content rather than replacing its render traversal.

## Panels and visual decorations

A Panel containing paginated content preserves its insets during both measurement and traversal. Its background is scheduled and clipped separately on each source page containing its content, behind the drawn cells, instead of being painted only at the first page's virtual origin. A Panel without internally paginating content is an ordinary indivisible renderable.

Page chrome (background, header, footer, overlay) remains the responsibility of `PDFGenerator`; its reserved content insets are accounted for in the planner's first-page and later-page placements.

## Oversized content

A logical unit taller than the printable page is **not fragmented** unless an explicit nested group provides a legal break inside it. The unit remains one drawing unit and may extend beyond the printable page bounds, subject to PDF clipping. A following unit can begin on another page.

## Page counts, positions, and selected-page rendering

Pagination completes its assignments **before** PDF page drawing, so `PageContext.count` describes the full source document. Selecting a page range suppresses unselected source pages without changing source page numbers. `PaginationPosition` records the position of a section's first drawable unit on the pages actually rendered.

## API migration

The former `PaginationGroup(sectionID:behavior:groupGap:dimension:content:)` initializer and `Renderable` conformance are removed. Callers must provide their layout container explicitly. `Grid` receives directives in its builder but lays out only their actual renderables. This is an intentionally breaking change, not a compatibility layer.

## Required regression invariants

1. Existing Grids without pagination directives have identical cells, measurements, and ordinary callback behavior.
2. A group's presence never increases Grid cell count or duplicates content measurement.
3. Parent and child `.page` at the same boundary never cause a blank intervening page.
4. Nested `.keepWith` affects the first unit, never the entire subtree implicitly.
5. Ordinary, ungrouped content does not acquire new break permissions.
6. Each selected source page begins exactly once, with consistent content origin and page chrome.
7. Content and Panel/track decorations are correctly positioned and clipped on each rendered page.
8. Repeated layout measurement or PDF generation cannot accumulate stale scope registrations or old page placements.
