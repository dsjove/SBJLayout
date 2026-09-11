# SwiftUI PDF Hosting

SBJLayout renders PDFs with Core Graphics and owns the generic reusable SwiftUI/PDFKit presentation layer. Applications choose presentation policy (for example, whether a particular idiom/window size should use a continuous reader or a two-page book), but they should not reimplement PDF viewers, page grouping, page navigation, document transitions, or pagination-position navigation.

The hosting boundary is:

```text
application layout policy
        ↓
PDFPresentationView / PDFPagedView / PageManagementView
        ↓
PDFPresentationController / PDFViewController / PDFPagedViewController
        ↓
StablePDFView / PDFPageView
        ↓
PDFView
```

## Continuous PDFs

`StablePDFView` owns the interactive PDFKit `PDFView` used for continuous scrolling. `PDFViewController` is the SwiftUI-facing control surface for that bridge. It owns the weak `PDFView` reference and contains PDFKit-specific behavior:

- first/previous/next/last-page navigation;
- current-page observation;
- navigation to `PaginationPosition` geometry;
- conversion from generated-PDF geometry into the displayed `PDFView` coordinate system;
- waiting for PDFKit destination navigation to visually settle when converted geometry is needed.

Raw `PDFView` instances should not escape from SBJLayout into application SwiftUI.

## Paged and facing-page PDFs

`PDFPagedView` composes a fixed number of pages side-by-side. The number of pages is data (`pagesPerView`), not a separate presentation type. A value of 1 is a single-page reader; 2 is a facing-page/book reader.

`PDFPagedViewController` owns grouped-page navigation and normalizes its first visible page to the current group size. Do not introduce separate single-page and dual-page controllers/views when `pagesPerView` expresses the difference.

`PDFPageView` is the low-level host for one PDF page used by `PDFPagedView`. `StablePDFPageView` remains only as a compatibility typealias.

## Shared presentation state

`PDFPresentationController<Input, PositionID>` owns reusable presentation mechanics that should not be duplicated in applications:

- current/outgoing document replacement state;
- cross-fade state;
- continuous and paged navigation controllers;
- deferred navigation to generated `PaginationPosition` values;
- viewport-resize re-navigation while PDFKit settles;
- transient highlight geometry and animation state.

`PDFPresentationView` renders that state. Its style is either `.continuous` or `.paged(pagesPerView:)`.

Applications remain responsible for deciding which style to use based on idiom, size, window arrangement, or product semantics.

## Shared page chrome

Both `PDFViewController` and `PDFPagedViewController` conform to `PDFPageNavigating`. `PageManagementView` is generic over that protocol, so the same button builder/chrome is used for continuous, one-page, and multi-page presentations.

## Minimum zoom policy

SBJLayout's PDFKit hosts clamp the minimum scale to the current `scaleFactorForSizeToFit`. A reader may zoom in, but cannot pinch a page smaller than its fitted viewport because that state only exposes empty canvas. The clamp is recalculated during `PDFView` layout so the floor follows rotation, window resizing, split-view changes, and other viewport changes.
