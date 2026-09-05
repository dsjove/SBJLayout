# SBJLayout

SBJLayout is the SBJ framework for **newspaper/print-style paginated layout and PDF generation** on iOS. It is a declarative, measure-first layout engine over Core Graphics/UIKit/PDFKit rather than a reactive UI framework.

SBJFoundation supplies shared platform primitives and presentation-resource semantics; SBJLayout owns print geometry, pagination, measurement, fitting, and PDF rendering.

The core model is deliberately small:

- `Renderable` values measure themselves for supplied bounds, then render into an allocated rectangle.
- `Grid` is the primary layout primitive.
- `Track`, `TrackSize`, and `TrackFactory` describe column and row sizing.
- `Insets`, `Alignment`, `Aspect`, and `AspectRatio` provide reusable geometry behavior.
- `Pagination` and `PaginationGroup` split measured content into pages.
- `PDFGenerator` renders a `Renderable` tree into PDF data.
- `JCSText`, `JCSImage`, `JCSRect`, and `JCSLine` provide basic UIKit/Core Graphics content and drawing wrappers.
- `Jargon` is an experimental/legacy document-wording prototype retained temporarily while the shared SBJFoundation localization/presentation-resource design is developed.

SBJLayout currently targets **iOS 17+** and requires **Swift 6.4**.

## Layout model

A `Renderable` participates in two phases:

```swift
let measured = content.measure(bounds: bounds)
content.render(in: allocated, measured: measured, align: .leftTop)
```

Measurement is superview-driven: parents supply bounds and children return their intrinsic result within those bounds. Rendering receives both the allocated rectangle and the previously measured content size.

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

### Track sizes

`TrackSize` supports:

- `.fixed(value)` — fixed length; negative values resolve to zero.
- `.intrinsic(bound:min:)` — measure cell content with a suggested bound and optional minimum.
- `.uniform(reduce:)` — measure uniform candidates and apply a reducer, `max` by default.
- `.fill(fraction:min:max:ifContent:)` — consume remaining bounded space subject to fraction/min/max rules. With `ifContent: true`, the fill track collapses when its intrinsic aggregate on that axis is zero.

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

`JCSText` currently supports verbatim text plus the experimental Jargon lookup/formatting path, minimum character width, line-height constraints, and horizontal/vertical alignment. The planned shared-resource/fitting API is defined canonically in `SBJFoundation/Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md`; `Documentation/LOCALIZATION_DESIGN.md` is only a local navigation stub.

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

`PaginationGroup` registers itself with the current `Pagination`, measures its grid, and supports three behaviors:

- `.flow` — normal page flow.
- `.keepWith` — attach the group to the preceding pagination unit where possible.
- `.page` — force a page break before the group.

Pagination is measurement-driven: groups must be measured before their render positions are resolved.

## PDF generation

`PDFGenerator.render(...)` returns PDF `Data`. `form(...)` additionally creates a `PDFDocument` when PDFKit can open the rendered data.

SwiftUI helpers are included for displaying a `PDFDocument`, keeping PDFKit behind a stable `UIViewRepresentable` bridge, managing it through `PDFViewController`, and editing `PageLayout`. Application chrome and overlays remain SwiftUI. See [PDF hosting](Documentation/PDF_HOSTING.md).

## Design assumptions and intentional limits

SBJLayout is for static document layout, not dynamic application UI. It intentionally does not attempt to provide live collection diffing, scrolling, animation, or reactive invalidation.

Current grid work is row-major and non-spanning. Track spans, wrapping, cross-grid sizing synchronization, dynamic spacer-style gaps, lexical alignment, and similar advanced table features are future features rather than compatibility obligations.

## Tests

The test suite covers geometry helpers, alignment/aspect behavior, builders, track factories and allocation, grid definition/layout behavior, text measurement semantics, jargon, pagination, and unbounded sentinel handling.

Run with a Swift 6.4 toolchain:

```sh
swift test
```

## Localization and text fitting design

The planned shared localization/text-fitting architecture, including the future replacement for experimental `Jargon` and the `JCSText` measure/draw retry requirements, is defined canonically in `SBJFoundation/Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md`. `Documentation/LOCALIZATION_DESIGN.md` remains only as a navigation stub.


## Documentation

Design and architecture documents live in `Documentation/`. Shared localization/presentation-resource design is intentionally centralized in `SBJFoundation/Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md`.


## Physical units

The layout engine continues to store geometry in PDF/Core Graphics points. Page-layout presentation now uses SBJFoundation `UnitValue<LengthUnit>` for conversion to inches or millimeters, and `PageLayout.pageWidth` / `pageHeight` expose physical dimensions as unit values. `PageLayoutEditorCore` also uses the shared `UnitValueControl` for margin editing, fixing the displayed unit to inches for North American/photo pages and millimeters for ISO A pages.
