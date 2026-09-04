# SBJLayout Documents

SBJLayout is specifically the newspaper/print-style paginated layout and PDF framework.
Detailed architecture/design notes live in this directory.

- [SwiftUI PDF hosting](PDF_HOSTING.md) — the intentional PDFKit/UIKit boundary and SwiftUI-facing controller.
- [Localization and text fitting](LOCALIZATION_DESIGN.md) — SBJLayout's role in the shared
  SBJFoundation presentation-resource design, including measure/draw candidate selection.

SBJFoundation owns shared platform and presentation-resource semantics. SBJLayout should keep
its own APIs focused on layout geometry, pagination, measurement, fitting, and PDF rendering.
