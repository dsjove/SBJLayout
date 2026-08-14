/// Controls behavior of an array property in `@CodableEditor`.
///
/// Arrays are reorderable by default. Set `ordering: false` when element order
/// has no meaning. `title` optionally names a stored property of each element
/// whose value should be used as the element heading.
///
/// Example:
/// ```swift
/// @EditorArray(title: "name")
/// var attacks: [Attack]
/// ```
@attached(peer)
public macro EditorArray(
    ordering: Bool = true,
    title: String? = nil
) = #externalMacro(
    module: "SBJLayoutMacros",
    type: "EditorArrayMacro"
)
