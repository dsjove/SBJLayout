# Codable Editor

`@CodableEditor` synthesizes writable field metadata for mutable stored properties on a `Codable` struct. If the struct declares `CodingKeys`, only those coded properties are included.

```swift
@CodableEditor
struct Character: Codable {
    var name: String
    var level: Int
    var attacks: [Attack]
    var background: Background?
}
```

Present it with SwiftUI:

```swift
SBJCodableEditor(value: $character, registry: editorRegistry)
```

## Custom application types

SBJLayout does not need to know domain-specific types. Register an exact type with `SBJEditorRegistry`:

```swift
var registry = SBJEditorRegistry()
registry.register(DiceExpression.self) { label, value, _ in
    DiceExpressionEditor(label: label, value: value)
}
registry.registerCreator(DiceExpression.self) {
    DiceExpression(count: 1, sides: 6, modifier: 0)
}
```

The custom editor receives a real `Binding<DiceExpression>`, so it can expose fields and actions such as a Roll button. Registration takes precedence over built-in editing.

Arrays use the registry's creator when `+` is tapped. Nil optionals use the same creator to create a value. Types may alternatively conform to `SBJEditorCreatable`.

Enums can conform to `SBJEditableEnum` to receive a menu picker automatically.

## Associated-value enums

`@CodableEditor` may be attached directly to a `Codable` enum. The editor renders
an enum case selector followed by recursively generated controls for the selected
case's associated values. Associated-value bindings reconstruct the enum whenever
one value changes, preserving the other values in the selected case.

```swift
@CodableEditor
enum Rule: Codable {
    case automatic
    case adjusted(amount: Int, enabled: Bool)
    case fixed(Int)
}
```

When switching cases, SBJLayout creates initial associated values from built-in
primitive defaults or `SBJEditorCreatable`. A case whose associated values cannot
be created is shown but disabled in the case menu. Application-registered custom
editors still take precedence over macro-generated enum editing.
