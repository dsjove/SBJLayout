/// Adds floating-point range validation metadata to a property handled by `@CodableEditor`.
@attached(peer)
public macro EditorNumber(range: ClosedRange<Double>) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorNumberMacro"
)
