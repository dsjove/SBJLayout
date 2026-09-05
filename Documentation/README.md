# SBJLayout Documents

SBJLayout is specifically the newspaper/print-style paginated layout and PDF framework.
Detailed architecture/design notes live in this directory.

- [SwiftUI PDF hosting](PDF_HOSTING.md) — the intentional PDFKit/UIKit boundary and SwiftUI-facing controller.
- [Localization and presentation resources](LOCALIZATION_DESIGN.md) — navigation to the canonical design in SBJFoundation. The design itself is not duplicated in SBJLayout.

SBJFoundation owns shared platform and presentation-resource semantics. SBJLayout should keep
its own APIs focused on layout geometry, pagination, measurement, fitting, and PDF rendering.


- [Pre-localization audit](PRELOCALIZATION_AUDIT.md)
