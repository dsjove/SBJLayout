/// Adds integer editing metadata to a property handled by `@CodableEditor`.
///
/// A closed `range` constrains both bounds. `min` constrains only the lower
/// bound. Constrained integer editors validate typed input and provide a
/// stepper within the effective range.
@attached(peer)
public macro EditorInteger(range: ClosedRange<Int>) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorIntegerMacro"
)

@attached(peer)
public macro EditorInteger(min: Int) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorIntegerMacro"
)
