# Tag Rendering

SBJLayout owns printable/Core Graphics tag representation because layout and
measurement are rendering concerns. The tag model contracts and SwiftUI controls
live in SBJFoundation/Tags.

`TagRenderable` mirrors the generic tag chip presentation: bold caption text,
tag color fill, contrast-aware foreground color, and reserved primary-selection
stroke space so toggling primary state does not alter layout.

Any `Tagging` value can produce a renderable with:

```swift
let tag = modelTag.renderable(isPrimary: true)
```

Use the result as an ordinary `Renderable`, including inside `Grid` with
horizontal wrapping. Domain apps should not add PDF-only drawing extensions to
their tag model.
