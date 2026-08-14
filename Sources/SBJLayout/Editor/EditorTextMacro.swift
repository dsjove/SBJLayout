/// Controls how a text property is presented and locally validated by `@CodableEditor`.
public enum SBJEditorTextStyle: Sendable {
    case singleLine
    case multiline
}

/// Unannotated `String` values default to `.singleLine`. Length constraints are
/// optional and are emitted into the containing type's generated `_invariant`.
@attached(peer)
public macro EditorText(
    _ style: SBJEditorTextStyle = .singleLine,
    minLength: Int? = nil,
    maxLength: Int? = nil
) = #externalMacro(module: "SBJLayoutMacros", type: "EditorTextMacro")
