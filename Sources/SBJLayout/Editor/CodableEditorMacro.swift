/// Generates editable metadata for a `Codable` structure or enum.
///
/// For structures, stored writable properties become recursive editor fields.
/// Immutable `let` properties produce a warning unless explicitly marked
/// `@NotEditable`.
///
/// For enums, each case becomes a selection and its associated values become
/// recursively editable fields. Changing an associated value reconstructs the
/// enum case while preserving the other associated values.
@attached(
    member,
    names: named(sbjEditorFields), named(sbjEditorEnumCases), named(sbjCreateEditorValue), named(sbjCreateEditorValueIfPossible), named(_hasContent), named(hasContent)
)
@attached(extension, conformances: SBJEditable, SBJEditableAssociatedEnum)
public macro CodableEditor() = #externalMacro(
    module: "SBJLayoutMacros",
    type: "CodableEditorMacro"
)
