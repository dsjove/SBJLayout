import SwiftUI

/// Application-supplied custom editors and value factories.
///
/// The registry intentionally matches exact Swift types. SBJLayout's built-in
/// renderer handles its generic categories first-class; applications use this
/// registry for domain values such as dice expressions, money, coordinates, or
/// application-specific identifiers.
public struct SBJEditorRegistry {
    private var editors: [ObjectIdentifier: Any] = [:]
    private var creators: [ObjectIdentifier: Any] = [:]

    public init() {}

    /// Registers a custom SwiftUI editor for one exact value type.
    ///
    /// A custom editor takes precedence over SBJLayout's built-in rendering.
    @MainActor
    public mutating func register<Value, Content: View>(
        _ type: Value.Type,
        @ViewBuilder editor: @escaping @MainActor (
            _ label: String,
            _ value: Binding<Value>,
            _ registry: SBJEditorRegistry
        ) -> Content
    ) {
        editors[ObjectIdentifier(type)] = SBJEditorRegistration<Value> { label, binding, registry in
            AnyView(editor(label, binding, registry))
        }
    }

    /// Registers a factory used by collection `+` controls and nil optionals.
    public mutating func registerCreator<Value>(
        _ type: Value.Type,
        create: @escaping () -> Value
    ) {
        creators[ObjectIdentifier(type)] = SBJCreatorRegistration<Value>(create: create)
    }

    func hasCustomEditor<Value>(_ type: Value.Type) -> Bool {
        editors[ObjectIdentifier(type)] != nil
    }

    @MainActor
    func customEditor<Value>(
        label: String,
        binding: Binding<Value>
    ) -> AnyView? {
        guard let registration = editors[ObjectIdentifier(Value.self)] as? SBJEditorRegistration<Value> else {
            return nil
        }
        return registration.makeView(label, binding, self)
    }

    func createArrayElement<Value>(_ type: Value.Type, existing: [Value]) -> Value? {
        if let arrayCreatableType = type as? any SBJEditorArrayCreatable.Type,
           let value = arrayCreatableType._sbjCreateEditorValue(existing: existing) as? Value {
            return value
        }
        return create(type)
    }

    func create<Value>(_ type: Value.Type) -> Value? {
        if let registration = creators[ObjectIdentifier(type)] as? SBJCreatorRegistration<Value> {
            return registration.create()
        }

        if let associatedEnumType = type as? any SBJEditableAssociatedEnum.Type,
           let value = associatedEnumType.sbjCreateEditorValueIfPossible() as? Value {
            return value
        }

        if let creatableType = type as? any SBJEditorCreatable.Type,
           let value = creatableType.sbjCreateEditorValue() as? Value {
            return value
        }

        return SBJBuiltinDefaultValue.make(type)
    }
}

private struct SBJEditorRegistration<Value> {
    let makeView: @MainActor (String, Binding<Value>, SBJEditorRegistry) -> AnyView
}

private struct SBJCreatorRegistration<Value> {
    let create: () -> Value
}

private enum SBJBuiltinDefaultValue {
    static func make<Value>(_ type: Value.Type) -> Value? {
        switch type {
        case is String.Type: return "" as? Value
        case is Int.Type: return 0 as? Value
        case is Int8.Type: return Int8(0) as? Value
        case is Int16.Type: return Int16(0) as? Value
        case is Int32.Type: return Int32(0) as? Value
        case is Int64.Type: return Int64(0) as? Value
        case is UInt.Type: return UInt(0) as? Value
        case is UInt8.Type: return UInt8(0) as? Value
        case is UInt16.Type: return UInt16(0) as? Value
        case is UInt32.Type: return UInt32(0) as? Value
        case is UInt64.Type: return UInt64(0) as? Value
        case is Double.Type: return 0.0 as? Value
        case is Float.Type: return Float(0) as? Value
        case is Bool.Type: return false as? Value
        default: return nil
        }
    }
}
