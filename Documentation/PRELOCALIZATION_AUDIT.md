# Pre-Localization Audit

> **Non-normative inventory/checklist.** Canonical localization and presentation-resource design lives in `SBJFoundation/Documentation/LOCALIZATION_AND_PRESENTATION_RESOURCES.md`.

## Formatting and locale

SBJLayout currently has no locale-dependent number/date formatter usage in active source. This is desirable: Layout should measure/render resolved presentation candidates rather than decide locale policy.

## Images/colors

`PageManagementView` now routes its symbols through SBJFoundation `ImageName`. Drawing colors elsewhere are rendering/theme data rather than UI semantic-state colors.

## Accessibility and framework copy

Page-navigation accessibility labels are framework-owned presentation vocabulary and must move through the eventual presentation-resource system.

## Public API

The framework has a broad layout DSL surface. No access changes were made as part of the localization audit. `PDFViewController`/`StablePDFView` intentionally expose a SwiftUI-facing bridge while keeping raw `PDFView` private.

## Dependency/platform boundary

SBJLayout depends only on SBJFoundation. UIKit/CoreGraphics/PDFKit usage is intrinsic to text/image measurement, PDF generation, and the narrow PDF viewer bridge.

## Dead/duplicate code

`Jargon` remains the notable pre-localization migration item. It is still wired through `RenderableContext` and `PDFGenerator`, so it is not dead code, but domain terminology does not belong in Layout long-term. Its sparse-override behavior is useful design evidence and should be replaced by the shared presentation-resource context during localization, then removed from Layout.

The app's `PageLayoutEditorView` is a presentation/persistence adapter around SBJLayout's `PageLayoutEditorCore`, not a duplicate implementation.

## Tests

Current layout/pagination/text and PageLayout-unit tests are sufficient before localization. The future candidate-selection implementation will need tests guaranteeing that the candidate chosen during measurement is the one used during drawing/pagination.
