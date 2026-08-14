import SwiftUI

/// Metadata for one associated value belonging to an enum case synthesized by
/// ``CodableEditor()``.
@MainActor
public struct SBJEditorAssociatedValue<Root> {
    public let name: String
    private let makeView: (Binding<Root>, Root?, SBJEditorRegistry, SBJEditorFocusRequest?) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorIssue]
    private let matchesSearch: (Root, String, SBJEditorRegistry) -> Bool
    private let hasChanged: (Root, Root?) -> Bool
    private let hasContent: (Root) -> Bool?
    private let containsEmptyContent: (Root, SBJEditorRegistry) -> Bool

    public init<Value: Codable>(
        name: String,
        get: @escaping (Root) -> Value,
        set: @escaping (inout Root, Value) -> Void
    ) {
        self.name = name
        self.makeView = { root, originalRoot, registry, focusRequest in
            let binding = Binding<Value>(
                get: { get(root.wrappedValue) },
                set: { newValue in
                    var current = root.wrappedValue
                    set(&current, newValue)
                    root.wrappedValue = current
                }
            )
            let originalValue = originalRoot.map(get)
            return SBJValueEditor.makeView(
                label: name,
                value: binding,
                originalValue: originalValue.map { SBJEditorOriginalValue($0) },
                registry: registry,
                focusRequest: focusRequest
            )
        }
        self.collectIssues = { root, path, registry in
            SBJValueEditor.collectIssues(
                value: get(root),
                path: path + [name],
                registry: registry
            )
        }
        self.matchesSearch = { root, query, registry in
            SBJValueEditor.matchesSearch(
                label: name,
                value: get(root),
                query: query,
                registry: registry
            )
        }
        self.hasChanged = { root, originalRoot in
            guard let originalRoot else { return true }
            return SBJEditorChangeComparison.isChanged(get(root), from: get(originalRoot))
        }
        self.hasContent = { root in
            (get(root) as? any HasContentCheckable)?.hasContent
        }
        self.containsEmptyContent = { root, registry in
            SBJValueEditor.containsEmptyContent(value: get(root), registry: registry)
        }
    }

    func view(
        root: Binding<Root>,
        originalRoot: Root?,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest?
    ) -> AnyView {
        let changed = hasChanged(root.wrappedValue, originalRoot)
        let contentState = hasContent(root.wrappedValue)
        let content = makeView(root, originalRoot, registry, focusRequest)
            .environment(\.sbjEditorIsChanged, changed)
            .environment(\.sbjEditorHasContent, contentState)
        return AnyView(
            SBJEditorFilteredView(
                content: AnyView(content),
                isChanged: changed,
                matchesSearch: { query in matchesSearch(root.wrappedValue, query, registry) },
                containsEmptyContent: { containsEmptyContent(root.wrappedValue, registry) }
            )
        )
    }

    func containsEmptyContent(
        root: Root,
        registry: SBJEditorRegistry
    ) -> Bool {
        containsEmptyContent(root, registry)
    }

    func issues(
        root: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorIssue] {
        collectIssues(root, path, registry)
    }
}

/// Metadata for one case of an associated-value enum synthesized by
/// ``CodableEditor()``.
@MainActor
public struct SBJEditorEnumCase<Root> {
    public let name: String
    public let associatedValues: [SBJEditorAssociatedValue<Root>]
    private let matchesValue: (Root) -> Bool
    private let createValue: () -> Root?

    public init(
        name: String,
        matches: @escaping (Root) -> Bool,
        makeDefault: @escaping () -> Root?,
        associatedValues: [SBJEditorAssociatedValue<Root>] = []
    ) {
        self.name = name
        self.matchesValue = matches
        self.createValue = makeDefault
        self.associatedValues = associatedValues
    }

    public func matches(_ value: Root) -> Bool {
        matchesValue(value)
    }

    public func makeDefaultValue() -> Root? {
        createValue()
    }

    var canCreate: Bool {
        createValue() != nil
    }

    func containsEmptyContent(
        value: Root,
        registry: SBJEditorRegistry
    ) -> Bool {
        guard matches(value) else { return false }
        return associatedValues.contains { field in
            field.containsEmptyContent(root: value, registry: registry)
        }
    }

    func issues(
        value: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorIssue] {
        guard matches(value) else { return [] }
        return associatedValues.flatMap { field in
            field.issues(root: value, path: path, registry: registry)
        }
    }
}

/// An enum whose cases and associated values can be edited recursively.
///
/// This conformance is normally synthesized by ``CodableEditor()`` when the
/// macro is attached to an enum declaration.
public protocol SBJEditableAssociatedEnum: Codable, SBJEditorCreatable, HasContentCheckable {
    @MainActor
    static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] { get }

    /// Failable creation used by optionals, arrays, and enclosing associated
    /// enums. The macro tries each case in declaration order and returns the
    /// first one whose associated values can all be created.
    static func sbjCreateEditorValueIfPossible() -> Self?
}

public extension SBJEditableAssociatedEnum {
    /// Associated-value enums are atomic selections by default. A domain type
    /// can override this when one of its cases represents an empty/default value.
    var hasContent: Bool { true }

    @MainActor
    internal static func _sbjMakeAssociatedEnumEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false
    ) -> AnyView {
        let typedBinding = Binding<Self>(
            get: { binding.get() as! Self },
            set: { binding.set($0) }
        )
        return AnyView(
            SBJAssociatedEnumEditor(
                label: label,
                value: typedBinding,
                originalValue: originalValue.map { $0.value(as: Self.self) },
                registry: registry,
                focusRequest: focusRequest,
                labelIsUnknown: labelIsUnknown
            )
        )
    }

    @MainActor
    internal static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool {
        guard let typed = value as? Self else { return false }
        if !typed.hasContent { return true }
        guard let selected = sbjEditorEnumCases.first(where: { $0.matches(typed) }) else {
            return false
        }
        return selected.containsEmptyContent(value: typed, registry: registry)
    }

    @MainActor
    internal static func _sbjCollectAssociatedEnumIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorIssue] {
        guard let typed = value as? Self,
              let selected = sbjEditorEnumCases.first(where: { $0.matches(typed) }) else {
            return [
                SBJEditorIssue(
                    path: path.joined(separator: " • "),
                    typeName: String(describing: Self.self),
                    valueDescription: SBJEditorValueDescription.describe(value)
                )
            ]
        }
        return selected.issues(value: typed, path: path, registry: registry)
    }
}

/// Default-value support used by macro-generated enum case constructors.
/// Applications can extend creation behavior by conforming their types to
/// ``SBJEditorCreatable``.
public enum SBJEditorDefaultValue {
    public static func value<T>(for type: T.Type) -> T? {
        if T.self == String.self { return "" as? T }
        if T.self == Bool.self { return false as? T }
        if T.self == Int.self { return 0 as? T }
        if T.self == Double.self { return 0.0 as? T }
        if T.self == Float.self { return Float(0) as? T }
        if let associatedEnum = T.self as? any SBJEditableAssociatedEnum.Type {
            return associatedEnum.sbjCreateEditorValueIfPossible() as? T
        }
        if let creatable = T.self as? any SBJEditorCreatable.Type {
            return creatable.sbjCreateEditorValue() as? T
        }
        return nil
    }
}

@MainActor
private struct SBJAssociatedEnumEditor<Value: SBJEditableAssociatedEnum>: View {
    let label: String
    @Binding var value: Value
    let originalValue: Value?
    let registry: SBJEditorRegistry
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool

    private var selectedCase: SBJEditorEnumCase<Value>? {
        Value.sbjEditorEnumCases.first(where: { $0.matches(value) })
    }

    private var originalForSelectedCase: Value? {
        guard let originalValue, let selectedCase else { return nil }
        return selectedCase.matches(originalValue) ? originalValue : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                SBJAssociatedEnumLabel(text: label, isUnknown: labelIsUnknown)
                Menu {
                    ForEach(Array(Value.sbjEditorEnumCases.enumerated()), id: \.offset) { _, enumCase in
                        Button(enumCase.name) {
                            if let replacement = enumCase.makeDefaultValue() {
                                value = replacement
                            }
                        }
                        .disabled(!enumCase.canCreate)
                    }
                } label: {
                    Text(selectedCase?.name ?? "Unknown")
                }
                .fixedSize()
                Spacer(minLength: 0)
            }

            if let selectedCase, !selectedCase.associatedValues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(selectedCase.associatedValues.enumerated()), id: \.offset) { _, field in
                        field.view(
                            root: $value,
                            originalRoot: originalForSelectedCase,
                            registry: registry,
                            focusRequest: focusRequest
                        )
                    }
                }
                .padding(.leading, 30)
            }
        }
    }
}

private struct SBJAssociatedEnumLabel: View {
    let text: String
    let isUnknown: Bool

    var body: some View {
        HStack(spacing: 5) {
            SBJEditorChangeIndicator()
            SBJEditorEmptyContentIndicator()
            if isUnknown {
                Text(text).fontWeight(.semibold).italic()
            } else {
                Text(text)
            }
        }
    }
}
