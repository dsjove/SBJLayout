/// Adds integer editing metadata to a property handled by `@CodableEditor`.
///
/// When a range is supplied the integer editor validates typed input against
/// the range and adds an in-range stepper beside the text field.
@attached(peer)
public macro EditorInteger(range: ClosedRange<Int>) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorIntegerMacro"
)
