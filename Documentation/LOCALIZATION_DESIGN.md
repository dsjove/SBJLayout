# Localization and Text Fitting in SBJLayout

## Status

This document describes SBJLayout's role in the shared localization/text-presentation design owned primarily by SBJFoundation. It is a design document, not a description of an implemented API.

`Jargon` remains in the package for now but is experimental/unused and should not constrain the final design.

## Responsibility boundary

SBJLayout is a Core Graphics/UIKit/PDF layout engine. It should own:

- measuring localized/resolved text with the actual `UIFont` and geometric bounds;
- selecting among author-approved presentation candidates according to fit policy;
- preserving the selected candidate between measurement and drawing;
- line wrapping, explicit line limits, hyphenation/break behavior, and alignment;
- PDF/document rendering.

SBJLayout should not own:

- application language catalogs;
- vendor vocabulary policy;
- document jargon/terminology policy;
- server wording policy;
- app-specific `StringPresentable` conformances;
- automatic English abbreviation generation.

Those semantics belong in the shared Structure-side text resource/resolver and in the host application.

## Current `JCSText` state

`JCSText` currently accepts three conceptually different inputs:

1. `CustomStringConvertible` -> immediately flattened to `description` and passed as verbatim text;
2. a `String` interpreted as a `Jargon` key;
3. explicit `verbatim` `String`.

It also contains a typed Jargon formatter path.

This API predates the shared localization design and collapses too much information too early. The long-term API should make the distinction explicit:

```swift
JCSText(sharedTextResourceOrPresentation, ...)
JCSText(verbatim: runtimeString, ...)
```

The first form resolves through the Structure-side text context and retains alternate candidates until fit selection. The second is deliberately terminal text.

Do not add more Jargon/localization behavior directly to `JCSText` before the shared resource model exists.

## `Jargon` disposition

`Jargon` demonstrated two useful ideas:

- sparse overrides with inheritance;
- typed formatters associated with a text key.

It also mixes concerns that should be separated:

- document vocabulary;
- formatting;
- string lookup;
- render-environment propagation.

The final shared resolver may retain the sparse-provider concept, but `Jargon` itself should be removed from `RenderableContext` and `JCSText` once the Structure-side replacement is available.

Until then, leave it isolated rather than evolving it into the new API.

## Render context

`RenderableContext` currently contains `Pagination` and `Jargon`.

The expected direction is conceptually:

```text
RenderableContext
    pagination
    text/presentation context supplied by SBJFoundation
```

The shared context value should carry locale and configured resolver/provider state. SBJLayout may continue to propagate that value using its existing `TaskLocal` environment.

Do not use `Locale.current` as the only source of locale during PDF generation. A document render/test may intentionally use a locale different from the device's current locale.

## Measurement and retry problem

The TODO around adding a size/presentation class to measure/draw is part of localization, not just geometry.

A label can have several valid localized presentations, for example:

```text
Maximum Hit Points
Max Hit Points
Max HP
```

Those candidates can have very different measured sizes in each language and font. The layout engine therefore cannot select the wording before it knows the actual bounds, but the model/resource layer must define which alternatives are legitimate.

### Required invariant: measure and render must agree

SBJLayout's core contract is measure, then render. If measurement selects a compact candidate but rendering later selects the full candidate, the layout is invalid.

Any future retry API must therefore satisfy one of these strategies:

- measurement returns/caches a selection token that rendering reuses; or
- measurement and rendering receive the same explicit presentation tier/selection input; or
- candidate selection is guaranteed deterministic from immutable text/context plus the exact same constraints.

The current `measure(bounds:) -> CGSize` signature carries no selection result, so this must be resolved before fit-aware localized text is considered complete.

### Candidate choice should be per text element

A global “compact mode” for an entire page is insufficient. One cell may require an abbreviation while neighboring cells fit full wording.

A parent layout may still request a retry tier or policy, but the selected candidate must be representable per `JCSText` instance/cell.

### Candidate wording versus layout policy

The shared resource layer should provide legitimate wording candidates such as full/compact/abbreviated.

SBJLayout owns geometric policies such as:

- one versus multiple lines;
- word wrapping;
- truncation (where allowed);
- hyphenation/break behavior;
- measuring explicit localized line breaks;
- actual font metrics.

`StringPresentable.multiLineDescription` in the app currently often inserts line breaks mechanically. During migration, preserve it as a separate candidate only where the words/meaning actually differ; otherwise let Layout create the multiline shape from the same localized wording.

## Proposed fit flow

Conceptually:

```text
SBJTextResource
    -> shared resolver + RenderableContext.textContext
    -> localized ordered candidate set
    -> JCSText measures candidate 1
       -> fits: select it
       -> does not fit: measure candidate 2
       -> ...
    -> measurement records/reproduces selection
    -> render draws that selected candidate
```

The exact protocol changes are intentionally deferred until the Structure resource type is proven.

## Intrinsic sizing implications

A candidate change affects both width and height. Therefore candidate selection participates in intrinsic size, grid track resolution, row height, wrapping, pagination, and page breaks.

This means fit selection cannot be a last-second draw-time fallback. It must occur during the same measurement pass that determines grid and pagination geometry.

Grid measurement caches sizes by bounds today. If the future text context/presentation tier can vary while bounds remain equal, cache identity must include the relevant presentation revision/input or caches must be invalidated when that context changes.

## CharacterSheet / `StringPresentable` migration

CharacterSheet currently calls `.description`, `.abbreviation`, and `.multiLineDescription` before constructing `JCSText`. That means Layout receives only the chosen terminal `String` and has no opportunity to select a better candidate.

The migration target is for Character domain values to expose the shared text presentation/resource, then pass that to `JCSText` intact.

Examples that currently demonstrate the issue include:

- ability abbreviations in Core Stats/Skills;
- multiline stat labels;
- attack names/effects;
- unit-bearing quantities;
- table/header labels and composed phrases.

Do not move `StringPresentable` into SBJLayout. It is app-domain presentation and should collapse into the Structure-side shared contract.

## Formatting

`JCSText` should not format arbitrary domain values by string interpolation or server convention. Typed formatting should occur as part of shared resource resolution/domain presentation, using the active locale, before Core Graphics measurement.

Layout may still own typography-specific attributed-string construction after textual resolution.

## Accessibility

PDF text fitting and SwiftUI accessibility are separate consumers. Layout should not force the fitted abbreviation to become the accessibility/spoken representation used elsewhere.

If PDF accessibility/tagging is added later, it should be able to use the standard semantic resource independently of the visually fitted candidate.

## Tests required during migration

Add tests that cover:

- full candidate fits and is preferred;
- compact/abbreviated fallback when width tightens;
- localized candidates with different relative lengths;
- candidate selection changing intrinsic row height;
- measurement/render selection consistency;
- measurement cache invalidation when text context changes;
- explicit line limits and localized line breaks;
- right-to-left text measurement/rendering;
- pagination behavior when a candidate changes height.

## Migration sequence

1. Keep `Jargon` unchanged/isolated while Structure proves the shared resource type.
2. Add the shared text context to `RenderableContext` without removing current APIs.
3. Add a `JCSText` initializer for the shared resource/presentation.
4. Solve measure/render candidate-selection persistence and cache identity.
5. Migrate CharacterSheet call sites away from preselecting `StringPresentable` strings.
6. Remove the Jargon initializers/context once no consumer needs them.
7. Add advanced fit policies (hyphenation, discretionary breaks, etc.) only after the basic candidate contract is stable.

## Non-goals

- SBJLayout does not become a localization catalog manager.
- SBJLayout does not own vendor/document/server terminology.
- SBJLayout does not generate linguistic abbreviations.
- `JCSText` should not parse user-editable numeric/unit input; that belongs to Structure/UI controls and domain formatting.
