/// Controls behavior and local cardinality validation of an array property in `@CodableEditor`.
///
/// Arrays are reorderable by default. `title` is a compiler-checked key path to
/// the element property used as its heading. Presence/count requirements belong
/// to the owning property and can be expressed with `minCount`/`maxCount`.
@attached(peer)
public macro EditorArray(
    ordering: Bool = true,
    title: AnyKeyPath? = nil,
    minCount: Int? = nil,
    maxCount: Int? = nil
) = #externalMacro(module: "SBJLayoutMacros", type: "EditorArrayMacro")
