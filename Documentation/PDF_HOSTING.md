# SwiftUI PDF Hosting

SBJLayout renders PDFs with Core Graphics, but interactive display uses PDFKit. PDFKit's interactive viewer is `PDFView`, a UIKit class on iOS, so one UIKit bridge is intentionally retained.

The hosting boundary is:

```text
SwiftUI presentation / chrome / overlays
                ↓
        StablePDFView
        (UIViewRepresentable)
                ↓
            PDFView
```

`PDFViewController` is the SwiftUI-facing control surface for that bridge. It owns the weak `PDFView` reference and contains PDFKit-specific behavior:

- first/previous/next/last-page navigation;
- current-page observation;
- navigation to `PaginationPosition` geometry;
- conversion from generated-PDF geometry into the displayed `PDFView` coordinate system;
- waiting for PDFKit destination navigation to visually settle when converted geometry is needed.

Raw `PDFView` instances should not escape from `StablePDFView` into application SwiftUI. Application presentation code should use `PDFViewController` instead.

## What stays in SwiftUI

PDF-related application UI that is not intrinsically a PDFKit operation belongs in SwiftUI. Examples include:

- document cross-fades;
- section-selection highlights;
- toolbar composition;
- transient overlays and decoration;
- application selection/focus semantics.

In particular, a highlight corresponding to a `PaginationPosition` should request its converted rectangle from `PDFViewController` and draw/animate the highlight as a SwiftUI overlay. It should not add a UIKit subview to `PDFView`.

## Why geometry conversion remains in the bridge

A `PaginationPosition` is recorded in the Core Graphics coordinate space used to generate the PDF. Its on-screen rectangle depends on PDFKit state including page bounds, display box, zoom, scrolling, page spacing, and display mode. Conversion therefore belongs beside `PDFView`, even though the visual decoration using that rectangle belongs in SwiftUI.
