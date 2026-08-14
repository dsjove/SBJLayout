import SwiftUI

/// Type-erased metadata for one writable property on `Root`.
///
/// Editor fields are UI metadata: they hold SwiftUI bindings and view factories,
/// so the entire abstraction is isolated to the main actor. Keeping construction
/// and use in the same isolation domain also prevents writable key paths from
/// being transferred into a main-actor closure from a nonisolated context.
@MainActor
public struct SBJEditorField<Root> {
    public let name: String
    private let makeView: (Binding<Root>, Root?, SBJEditorRegistry, String?, SBJEditorFocusRequest?, Bool) -> AnyView
    private let collectIssues: (Root, [String], SBJEditorRegistry) -> [SBJEditorIssue]
    private let matchesSearch: (Root, String, SBJEditorRegistry) -> Bool
    private let hasChanged: (Root, Root?) -> Bool

    public init<Value: Codable>(
        name: String,
        _ keyPath: WritableKeyPath<Root, Value>,
        textStyle: SBJEditorTextStyle? = nil,
        integerRange: ClosedRange<Int>? = nil,
        arrayOrdering: Bool = true,
        arrayItemTitleKey: String? = nil
    ) {
        self.name = name
        self.makeView = { root, originalRoot, registry, overrideName, focusRequest, labelIsUnknown in
            let value = Binding<Value>(
                get: { root.wrappedValue[keyPath: keyPath] },
                set: { root.wrappedValue[keyPath: keyPath] = $0 }
            )
            let originalValue = originalRoot.map { $0[keyPath: keyPath] }
            return SBJValueEditor.makeView(
                label: overrideName ?? name,
                value: value,
                originalValue: originalValue.map { SBJEditorOriginalValue($0) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                arrayOrdering: arrayOrdering,
                arrayItemTitleKey: arrayItemTitleKey,
                focusRequest: focusRequest,
                labelIsUnknown: labelIsUnknown
            )
        }
        self.collectIssues = { root, path, registry in
            SBJValueEditor.collectIssues(
                value: root[keyPath: keyPath],
                path: path + [name],
                registry: registry,
                arrayItemTitleKey: arrayItemTitleKey
            )
        }
        self.matchesSearch = { root, query, registry in
            SBJValueEditor.matchesSearch(
                label: name,
                value: root[keyPath: keyPath],
                query: query,
                registry: registry,
                arrayItemTitleKey: arrayItemTitleKey
            )
        }
        self.hasChanged = { root, originalRoot in
            guard let originalRoot else { return true }
            return SBJEditorChangeComparison.isChanged(
                root[keyPath: keyPath],
                from: originalRoot[keyPath: keyPath]
            )
        }
    }

    func issues(
        root: Root,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorIssue] {
        collectIssues(root, path, registry)
    }

    func view(
        root: Binding<Root>,
        originalRoot: Root? = nil,
        registry: SBJEditorRegistry,
        nameOverride: String? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false
    ) -> AnyView {
        let changed = hasChanged(root.wrappedValue, originalRoot)
        let content = makeView(root, originalRoot, registry, nameOverride, focusRequest, labelIsUnknown)
            .environment(\.sbjEditorIsChanged, changed)
        return AnyView(
            SBJEditorFilteredView(
                content: AnyView(content),
                isChanged: changed,
                matchesSearch: { query in
                    matchesSearch(root.wrappedValue, query, registry)
                }
            )
        )
    }
}

@MainActor
struct SBJEditorFilteredView: View {
    let content: AnyView
    let isChanged: Bool
    let matchesSearch: (String) -> Bool
    @Environment(\.sbjEditorSearchQuery) private var query
    @Environment(\.sbjEditorShowChangedOnly) private var showChangedOnly

    @ViewBuilder
    var body: some View {
        if (!showChangedOnly || isChanged) && (query.isEmpty || matchesSearch(query)) {
            content
        }
    }
}
