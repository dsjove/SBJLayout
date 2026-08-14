/// Controls how a text property is presented by `@CodableEditor`.
public enum SBJEditorTextStyle: Sendable {
    case singleLine
    case multiline
}

/// Marks a coded property as single-line or multiline editable text.
///
/// Unannotated `String` values default to `.singleLine`.
/// The style also propagates through optionals and arrays of strings.
@attached(peer)
public macro EditorText(_ style: SBJEditorTextStyle) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorTextMacro"
)
