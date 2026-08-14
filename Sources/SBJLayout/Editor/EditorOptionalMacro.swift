/// Adds owner-level presence validation to an optional property handled by `@CodableEditor`.
@attached(peer)
public macro EditorOptional(required: Bool = true) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorOptionalMacro"
)
