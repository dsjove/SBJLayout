# SBJLayout

SBJLayout is the SBJ framework for **newspaper/print-style paginated layout and PDF generation** on iOS. It is a declarative, measure-first layout engine over Core Graphics/UIKit/PDFKit rather than a reactive UI framework.

SBJFoundation supplies shared platform primitives and presentation-resource semantics; SBJLayout owns print geometry, pagination, measurement, fitting, and PDF rendering.

The core model is deliberately small:

- `Renderable` values measure themselves for supplied bounds, then render into an allocated rectangle.
- `Grid` is the primary layout primitive.
- `Track`, `TrackSize`, and `TrackFactory` describe column and row sizing.
- `Insets`, `Alignment`, `Aspect`, and `AspectRatio` provide reusable geometry behavior.
- `PaginationGroup` declares logical pagination boundaries in a builder; `Pagination` assigns measured content units to pages without changing Grid cell counts.
- `PDFGenerator` renders a `Renderable` tree into PDF data.
- `JCSLink` adds hyperlink annotations around renderables without leaking Core Graphics PDF context handling to clients.
- `JCSText`, `JCSImage`, `JCSRect`, and `JCSLine` provide basic UIKit/Core Graphics content and drawing wrappers.
- `Jargon` is an experimental/legacy document-wording prototype retained temporarily while the shared SBJFoundation localization/presentation-resource design is developed.

SBJLayout currently targets **iOS 17+** and requires **Swift 6.4**.

## Layout model

A `Renderable` participates in measure/render phases:

```swift
let measured = content.measure(bounds: bounds)
content.render(in: allocated, measured: measured, align: .leftTop)
```

`TrackElement` also exposes `minimumMeasure(bounds:)`, a content-driven minimum-size probe used by layout when a flexible track must contribute meaningfully before a final bounded size exists. The default implementation delegates to ordinary `measure(bounds:)`; elements with a distinct minimum-content concept override it.

Measurement is superview-driven: parents supply bounds and children return their preferred result within those bounds. Rendering receives both the allocated rectangle and the previously measured content size. Minimum measurement is a separate geometric question and does not replace ordinary measurement.

`CGSize.unbounded` and `CGFloat.unbounded` are finite sentinels used where one or both dimensions are unconstrained. Code that participates in layout should preserve an unbounded dimension rather than performing normal finite-size arithmetic on it.

## Grid

`Grid` lays a linear cell array into row-major columns and rows. Columns and rows are described by `TrackFactory` values.

```swift
let grid = Grid(
    cols: .init([
        Track(.fixed(90), align: .right),
        Track(.fill(), align: .left),
    ]),
    rows: .init(gap: 6)
) {
    JCSText(verbatim: "Name")
    JCSText(verbatim: "Ada Lovelace")
}
```

Convenience initializers cover common shapes:

- `Grid(horzFlow:wrapped:rows:...)` creates a horizontal flow with an optional fixed wrap count.
- `Grid(vertFlow:rows:...)` creates a single-column vertical flow.
- `Grid(table:columnMap:header:leader:rows:...)` builds table-oriented columns and optional header/leader aggregation behavior.

Grid can also wrap resolved tracks against a bounded primary axis with `wrapping: .horizontal` or `wrapping: .vertical`. Wrapping changes only rendered geometry and intrinsic grid size; logical cell indices and row/column coordinates remain unchanged. A visible `.fill` track consumes the remainder of its current band and terminates that band. An unbounded primary axis does not wrap.

### Row accessories

A `Grid(table:)` column definition may be `.rowAccessory(placement:gap:align:)`. Its renderable remains in the flattened input sequence, but it is excluded from physical column sizing and rendered before or after the ordinary cells of its logical row at the full measured grid width.

```swift
Grid(table: [
    .init(.intrinsic()),
    .init(.fill()),
    .rowAccessory(placement: .after, gap: 4, align: .leftTop)
]) {
    for item in items {
        title(item)
        detail(item)
        notes(item)
    }
}
```

Multiple accessories may share a placement and appear anywhere in the flattened input definition. They stack in declaration order within each placement group, independently of where the slots occur relative to the ordinary columns:

```swift
Grid(table: [
    .rowAccessory(placement: .after, gap: 3),
    .init(.intrinsic()),
    .rowAccessory(placement: .before, gap: 2),
    .init(.fill()),
    .rowAccessory(placement: .after, gap: 4)
]) {
    for item in items {
        footer(item)
        title(item)
        introduction(item)
        detail(item)
        notes(item)
    }
}
```

- `placement` accepts `.before` and `.after` (the default). The gap separates the accessory from the ordinary cells in either position.
- Input stride counts the accessory; physical column count does not.
- Each row may contain any number of accessories, including repeated `.before` and `.after` placements; the same input stride applies to all rows, including headers.
- The accessory is measured after physical column sizes are resolved.
- A nonempty accessory adds its measured height plus its configured vertical gap to the row's intrinsic height.
- An empty (zero-height) accessory adds no gap.
- The accessory has its own alignment. Ordinary cells retain the existing union of row and column alignments.
- The accessory is sent to the existing cell rendering callback with `c == columnCount`.
- Existing grid instances without `.rowAccessory` preserve their input and sizing semantics.

## Limitations

General-purpose row/column spans are not implemented. Header input follows the same flattened stride. Table grids do not expose horizontal wrapping in their convenience initializer. Fixed-height row tracks may constrain content, including accessories. When accessories are present, column renderer callbacks receive ordinary-cell rectangles per row, so vertical separators stop before accessory content.

### Track sizes

`TrackSize` supports:

- `.fixed(value)` — fixed length; negative values resolve to zero.
- `.intrinsic(bound:min:)` — measure cell content with a suggested bound and optional minimum.
- `.uniform(reduce:)` — measure uniform candidates and apply a reducer, `max` by default.
- `.fill(fraction:min:max:ifContent:)` — consume remaining bounded space subject to fraction/min/max rules. With `ifContent: true`, the fill track collapses when its intrinsic aggregate on that axis is zero. During an unbounded Grid measurement, active fill tracks use their cells' minimum-content measurements and requested fractions to derive a minimum fill pool, then apply the same sequential Fill allocation rules. This gives fill descendants a nonzero intrinsic contribution when they are nested inside an intrinsic parent without changing normal bounded fill allocation.

`TrackArrangement` controls how tracks combine:

- `.tight` — adjacent tracks with no gaps.
- `.gaps` — uses the preceding visible track's gap between visible tracks.
- `.stack` — all tracks share the same origin and the axis size is the largest resolved track.

Zero-length tracks are not considered visible for gap placement or grid iteration.

### Measurement snapshots

`GridLayout.measure(bounds:)` returns a `GridDefinition` containing the resolved column metrics, row metrics, measured cell sizes, and bounds. `GridDefinition.iterate(...)` exposes immutable column/row/cell iteration records for custom rendering.

Cells beyond a row factory's `maxCount` are intentionally excluded. Minimum row counts may create trailing empty cells/rows, which are represented by `nil` cells during iteration.

## Geometry helpers

### Alignment

`Alignment` is an `OptionSet` supporting left/right/top/bottom and combined center values. An empty horizontal or vertical component defaults to left/top for positioning.

### Aspect

`Aspect` supports `.fit`, `.fill`, `.stretch`, and `.original`. Fit/fill preserve aspect ratio; empty or invalid source geometry resolves to `.zero` rather than producing NaN/infinite layout values.

### Insets

`Insets.apply(to:)` removes inset space; `inverse: true` adds it back. Unbounded dimensions remain unbounded.

## Text and images

`JCSText` currently supports verbatim text plus the experimental Jargon lookup/formatting path, minimum character width, line-height constraints, and horizontal/vertical alignment. Its minimum-content measurement uses the widest Foundation word segment for word wrapping and the widest extended grapheme cluster for character wrapping; `minChars` remains an adaptive character-based reserve. Clipping/truncation currently retain ordinary measurement semantics. The planned shared-resource/candidate-fitting API is described in `LOCALIZATION_DESIGN.md`.

`JCSImage` measures and renders a `UIImage` with `Aspect` behavior and optional rounded clipping. A nil image measures as zero for fit/fill layouts.

`JCSRect` and `JCSLine` are lightweight drawing helpers. Their configured stroke widths are applied when drawing.

## Jargon and render context

`Jargon` is retained as an experimental prototype, not the planned localization architecture. `RenderableEnvironment` currently stores a task-local `RenderableContext` containing the active `Pagination` and `Jargon`; the localization design replaces that text-policy role with a shared SBJFoundation presentation-resource context.

```swift
let jargon = Jargon(
    "Invoice",
    words: ["customer": "Client"],
    formatters: [
        "currency": JargonFormatter(Double.self) { value in
            value.formatted(.currency(code: "USD"))
        }
    ]
)
```

Use `RenderableEnvironment.withContext(...)` to render or measure with an explicit context. `JCSText` can resolve jargon keys or format values through that context.

## Pagination

`PageLayout` combines a `PageSize`, landscape flag, and margins. `PageSize` includes North American, ISO A-series, photo, zero/unbounded, and custom dimensions.

`PaginationGroup` is a **structural builder directive**, not a `Renderable` or a layout container. It does not create a Grid, measure content, or advance pages. The containing Grid measures its ordinary cells, while its `RenderableBuilder` keeps the groups' logical boundaries for the document-level paginator.

```swift
Grid(vertFlow: .init(.fill())) {
    PaginationGroup(sectionID: "spells") {          // .flow by default
        SectionTitle()
        PaginationGroup { WizardSpells() }
        PaginationGroup { ClericSpells() }
    }
}
```

The three behaviors are:

- `.flow` (default) — permits a page break before the group when necessary.
- `.keepWith` — Keep With Above: attach the first logical unit to the preceding unit.
- `.page` — force one page transition at the group's entry (coincident parent/child requirements collapse).

Content remains indivisible unless an authorized group boundary permits a split. Nested groups, oversize behavior, page decoration handling, and the rule forbidding splits within horizontal Grid rows are specified in [PaginationRules.md](Sources/SBJLayout/pagination/PaginationRules.md).

Pagination now performs **measurement, then a pre-render page-planning pass, then rendering**. The planner knows the complete page count before headers and footers are drawn. This change intentionally removes the old `PaginationGroup(sectionID:behavior:groupGap:dimension:content:)` layout-wrapper API; callers own their Grids explicitly.

## PDF generation

`PDFGenerator.render(...)` returns PDF `Data`. `form(...)` additionally creates a `PDFDocument` when PDFKit can open the rendered data. The generator also accepts optional title/creator metadata so clients do not need a second PDF-rendering layer solely to set document metadata.

SwiftUI helpers are included for displaying a `PDFDocument`, keeping PDFKit behind a stable `UIViewRepresentable` bridge, managing it through `PDFViewController`, and editing `PageLayout`. Application chrome and overlays remain SwiftUI. See [PDF hosting](Documentation/PDF_HOSTING.md).

## Design assumptions and intentional limits

SBJLayout is for static document layout, not dynamic application UI. It intentionally does not attempt to provide live collection diffing, scrolling, animation, or reactive invalidation.

Current grid work is row-major and does not implement general row/column spanning. Row accessories are supported in table grids, but arbitrary track spans, wrapping, cross-grid sizing synchronization, dynamic spacer-style gaps, lexical alignment, and similar advanced table features are future features rather than compatibility obligations.

## Tests

The test suite includes row-accessory measurement and geometry tests and covers geometry helpers, alignment/aspect behavior, builders, track factories and allocation, minimum-content and nested fill behavior, grid definition/layout behavior, text measurement semantics, jargon, pagination, and unbounded sentinel handling.

Run with a Swift 6.4 toolchain:

```sh
swift test
```

## Localization and text fitting design

The planned shared localization/text-fitting architecture, including the future replacement for experimental `Jargon` and the `JCSText` measure/draw retry requirements, is documented in [Documentation/LOCALIZATION_DESIGN.md](Documentation/LOCALIZATION_DESIGN.md).


## Documentation

Design and architecture documents live in `Documentation/`. The shared localization/presentation-resource work is described from Layout's perspective in [Documentation/LOCALIZATION_DESIGN.md](Documentation/LOCALIZATION_DESIGN.md).


## Physical units

The layout engine continues to store geometry in PDF/Core Graphics points. Page-layout presentation now uses SBJFoundation `UnitValue<LengthUnit>` for conversion to inches or millimeters, and `PageLayout.pageWidth` / `pageHeight` expose physical dimensions as unit values. `PageLayoutEditorCore` also uses the shared `UnitValueControl` for margin editing, fixing the displayed unit to inches for North American/photo pages and millimeters for ISO A pages.
