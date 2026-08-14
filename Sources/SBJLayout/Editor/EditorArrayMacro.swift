/// Controls behavior of an array property in `@CodableEditor`.
///
/// Arrays are reorderable by default. Set `ordering: false` when element order
/// has no meaning. `title` optionally identifies a stored property of each
/// element whose value should be used as the element heading.
///
/// Example:
/// ```swift
/// @EditorArray(title: \Attack.name)
/// var attacks: [Attack]
/// ```
@attached(peer)
public macro EditorArray(
    ordering: Bool = true,
    title: AnyKeyPath? = nil
) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorArrayMacro"
)
