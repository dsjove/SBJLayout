import SwiftUI

@MainActor
struct SBJEditorItemActions {
    let remove: () -> Void
    let moveUp: (() -> Void)?
    let moveDown: (() -> Void)?

    var leadingView: AnyView {
        AnyView(
            Button(action: remove) {
                Image(systemName: "minus.circle")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove item")
        )
    }

    var trailingView: AnyView {
        guard moveUp != nil || moveDown != nil else {
            return AnyView(EmptyView())
        }
        return AnyView(
            HStack(spacing: 6) {
                Button {
                    moveUp?()
                } label: {
                    Image(systemName: "arrow.up.circle")
                }
                .buttonStyle(.borderless)
                .disabled(moveUp == nil)
                .accessibilityLabel("Move item up")

                Button {
                    moveDown?()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .buttonStyle(.borderless)
                .disabled(moveDown == nil)
                .accessibilityLabel("Move item down")
            }
        )
    }
}

@MainActor
final class SBJEditorFocusRequest {
    private var claimed = false

    func claim() -> Bool {
        guard !claimed else { return false }
        claimed = true
        return true
    }
}

private protocol _SBJOptionalValue {
    @MainActor
    static func _sbjOptionalEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJEditorTextStyle?,
        integerRange: ClosedRange<Int>?,
        arrayOrdering: Bool,
        arrayItemTitleKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?
    ) -> AnyView
}

private protocol _SBJCollectionValue {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJEditorTextStyle?,
        integerRange: ClosedRange<Int>?,
        ordering: Bool,
        itemTitleKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?
    ) -> AnyView
}

private protocol _SBJOptionalIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        arrayItemTitleKey: String?
    ) -> [SBJEditorIssue]
}

private protocol _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorIssue]
}

private protocol _SBJOptionalContentValue {
    @MainActor
    static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool
}

private protocol _SBJCollectionContentValue {
    @MainActor
    static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool
}

extension Optional: _SBJOptionalContentValue {
    @MainActor
    static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool {
        guard let optional = value as? Wrapped?, let wrapped = optional else { return true }
        return SBJValueEditor.containsEmptyContent(value: wrapped, registry: registry)
    }
}

extension Array: _SBJCollectionContentValue {
    @MainActor
    static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool {
        guard let values = value as? [Element] else { return false }
        return values.contains { element in
            SBJValueEditor.containsEmptyContent(value: element, registry: registry)
        }
    }
}

extension Optional: _SBJOptionalIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        arrayItemTitleKey: String?
    ) -> [SBJEditorIssue] {
        guard let optional = value as? Wrapped?, let wrapped = optional else { return [] }
        return SBJValueEditor.collectIssues(
            value: wrapped,
            path: path,
            registry: registry,
            arrayItemTitleKey: arrayItemTitleKey
        )
    }
}

extension Array: _SBJCollectionIssueValue {
    @MainActor
    static func _sbjCollectEditorIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry,
        itemTitleKey: String?
    ) -> [SBJEditorIssue] {
        guard let values = value as? [Element] else { return [] }
        return values.enumerated().flatMap { offset, element in
            let title = SBJValueEditor.arrayItemTitle(
                element: element,
                index: offset,
                key: itemTitleKey
            )
            return SBJValueEditor.collectIssues(
                value: element,
                path: path + [title],
                registry: registry
            )
        }
    }
}

extension Optional: _SBJOptionalValue where Wrapped: Codable {
    @MainActor
    static func _sbjOptionalEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJEditorTextStyle?,
        integerRange: ClosedRange<Int>?,
        arrayOrdering: Bool,
        arrayItemTitleKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?
    ) -> AnyView {
        let typed = Binding<Wrapped?>(
            get: { binding.get() as! Wrapped? },
            set: { binding.set($0 as Any) }
        )
        return AnyView(
            SBJOptionalEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: Wrapped?.self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                arrayOrdering: arrayOrdering,
                arrayItemTitleKey: arrayItemTitleKey,
                itemActions: itemActions,
                focusRequest: focusRequest
            )
        )
    }
}

extension Array: _SBJCollectionValue where Element: Codable {
    @MainActor
    static func _sbjCollectionEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue?,
        registry: SBJEditorRegistry,
        textStyle: SBJEditorTextStyle?,
        integerRange: ClosedRange<Int>?,
        ordering: Bool,
        itemTitleKey: String?,
        itemActions: SBJEditorItemActions?,
        focusRequest: SBJEditorFocusRequest?
    ) -> AnyView {
        let typed = Binding<[Element]>(
            get: { binding.get() as! [Element] },
            set: { binding.set($0) }
        )
        return AnyView(
            SBJArrayEditor(
                label: label,
                value: typed,
                originalValue: originalValue.map { $0.value(as: [Element].self) },
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                ordering: ordering,
                itemTitleKey: itemTitleKey,
                itemActions: itemActions,
                focusRequest: focusRequest
            )
        )
    }
}

extension SBJEditableEnum {
    @MainActor
    fileprivate static func _makeEnumEditor(
        label: String,
        binding: SBJAnyBinding,
        labelIsUnknown: Bool = false
    ) -> AnyView {
        let typed = Binding<Self>(
            get: { binding.get() as! Self },
            set: { binding.set($0) }
        )
        return AnyView(SBJEnumEditor(label: label, value: typed, labelIsUnknown: labelIsUnknown))
    }
}

enum SBJValueEditor {
    @MainActor
    static func makeView<Value>(
        label: String,
        value: Binding<Value>,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        textStyle: SBJEditorTextStyle? = nil,
        integerRange: ClosedRange<Int>? = nil,
        arrayOrdering: Bool = true,
        arrayItemTitleKey: String? = nil,
        itemActions: SBJEditorItemActions? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        labelIsUnknown: Bool = false
    ) -> AnyView {
        if let custom = registry.customEditor(label: label, binding: value) {
            return wrapLeaf(custom, itemActions: itemActions)
        }

        if Value.self == String.self {
            let binding = castBinding(value, to: String.self)
            switch textStyle ?? .singleLine {
            case .singleLine:
                return wrapLeaf(AnyView(SBJSingleLineTextEditor(label: label, value: binding, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown)), itemActions: itemActions)
            case .multiline:
                return wrapLeaf(AnyView(SBJMultilineTextEditor(label: label, value: binding, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown)), itemActions: itemActions)
            }
        }
        if Value.self == Bool.self {
            let binding = castBinding(value, to: Bool.self)
            return wrapLeaf(AnyView(SBJBooleanEditor(label: label, value: binding, labelIsUnknown: labelIsUnknown)), itemActions: itemActions)
        }
        if Value.self == Int.self {
            return wrapLeaf(
                AnyView(SBJIntegerEditor(label: label, value: castBinding(value, to: Int.self), range: integerRange, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown)),
                itemActions: itemActions
            )
        }
        if Value.self == Double.self {
            return wrapLeaf(
                AnyView(SBJDoubleEditor(label: label, value: castBinding(value, to: Double.self), focusRequest: focusRequest, labelIsUnknown: labelIsUnknown)),
                itemActions: itemActions
            )
        }
        if Value.self == Float.self {
            let double = Binding<Double>(
                get: { Double(castBinding(value, to: Float.self).wrappedValue) },
                set: { castBinding(value, to: Float.self).wrappedValue = Float($0) }
            )
            return wrapLeaf(AnyView(SBJDoubleEditor(label: label, value: double, focusRequest: focusRequest, labelIsUnknown: labelIsUnknown)), itemActions: itemActions)
        }

        let erased = SBJAnyBinding(value)

        if let optional = Value.self as? any _SBJOptionalValue.Type {
            return optional._sbjOptionalEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                arrayOrdering: arrayOrdering,
                arrayItemTitleKey: arrayItemTitleKey,
                itemActions: itemActions,
                focusRequest: focusRequest
            )
        }
        if let collection = Value.self as? any _SBJCollectionValue.Type {
            return collection._sbjCollectionEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                textStyle: textStyle,
                integerRange: integerRange,
                ordering: arrayOrdering,
                itemTitleKey: arrayItemTitleKey,
                itemActions: itemActions,
                focusRequest: focusRequest
            )
        }
        if let associatedEnum = Value.self as? any SBJEditableAssociatedEnum.Type {
            return wrapLeaf(
                associatedEnum._sbjMakeAssociatedEnumEditor(
                    label: label,
                    binding: erased,
                    originalValue: originalValue,
                    registry: registry,
                    focusRequest: focusRequest,
                    labelIsUnknown: labelIsUnknown
                ),
                itemActions: itemActions
            )
        }
        if let editable = Value.self as? any SBJEditable.Type {
            return editable._sbjMakeEditor(
                label: label,
                binding: erased,
                originalValue: originalValue,
                registry: registry,
                itemActions: itemActions,
                focusRequest: focusRequest,
                titleIsUnknown: labelIsUnknown
            )
        }
        if let editableEnum = Value.self as? any SBJEditableEnum.Type {
            return wrapLeaf(
                editableEnum._makeEnumEditor(label: label, binding: erased, labelIsUnknown: labelIsUnknown),
                itemActions: itemActions
            )
        }

        // TODO: Extend the generic dispatcher for additional Codable shapes as needed.
        // In particular: Set needs uniqueness-safe editing and deterministic ordering;
        // Dictionary needs editable keys with collision handling (keys are not structural);
        // Date/Data/URL/UUID and non-enum RawRepresentable wrappers should get native
        // editors when client models begin relying on them.
        return wrapLeaf(
            AnyView(SBJUnsupportedEditor(label: label, type: Value.self, value: value.wrappedValue, labelIsUnknown: labelIsUnknown)),
            itemActions: itemActions
        )
    }

    @MainActor
    static func collectIssues<Value>(
        value: Value,
        path: [String],
        registry: SBJEditorRegistry,
        arrayItemTitleKey: String? = nil
    ) -> [SBJEditorIssue] {
        if registry.hasCustomEditor(Value.self) { return [] }
        if Value.self == String.self || Value.self == Bool.self || Value.self == Int.self ||
            Value.self == Double.self || Value.self == Float.self { return [] }

        if let optional = Value.self as? any _SBJOptionalIssueValue.Type {
            return optional._sbjCollectEditorIssues(
                value: value,
                path: path,
                registry: registry,
                arrayItemTitleKey: arrayItemTitleKey
            )
        }
        if let collection = Value.self as? any _SBJCollectionIssueValue.Type {
            return collection._sbjCollectEditorIssues(
                value: value,
                path: path,
                registry: registry,
                itemTitleKey: arrayItemTitleKey
            )
        }
        if let associatedEnum = Value.self as? any SBJEditableAssociatedEnum.Type {
            return associatedEnum._sbjCollectAssociatedEnumIssues(value: value, path: path, registry: registry)
        }
        if let editable = Value.self as? any SBJEditable.Type {
            return editable._sbjCollectIssues(value: value, path: path, registry: registry)
        }
        if Value.self is any SBJEditableEnum.Type { return [] }

        return [
            SBJEditorIssue(
                path: path.joined(separator: " • "),
                typeName: String(describing: Value.self),
                valueDescription: SBJEditorValueDescription.describe(value)
            )
        ]
    }

    @MainActor
    static func containsEmptyContent<Value>(
        value: Value,
        registry: SBJEditorRegistry
    ) -> Bool {
        if let checkable = value as? any HasContentCheckable, !checkable.hasContent {
            return true
        }

        if registry.hasCustomEditor(Value.self) { return false }

        if let optional = Value.self as? any _SBJOptionalContentValue.Type {
            return optional._sbjContainsEmptyContent(value: value, registry: registry)
        }
        if let collection = Value.self as? any _SBJCollectionContentValue.Type {
            return collection._sbjContainsEmptyContent(value: value, registry: registry)
        }
        if let associatedEnum = Value.self as? any SBJEditableAssociatedEnum.Type {
            return associatedEnum._sbjContainsEmptyContent(value: value, registry: registry)
        }
        if let editable = Value.self as? any SBJEditable.Type {
            return editable._sbjContainsEmptyContent(value: value, registry: registry)
        }

        return false
    }

    static func matchesSearch<Value>(
        label: String,
        value: Value,
        query: String,
        registry: SBJEditorRegistry,
        arrayItemTitleKey: String? = nil
    ) -> Bool {
        let needle = normalizedSearchText(query)
        guard !needle.isEmpty else { return true }

        if normalizedSearchText(label).contains(needle) { return true }
        if let description = SBJEditorValueDescription.describe(value),
           normalizedSearchText(description).contains(needle) { return true }
        if normalizedSearchText(String(describing: value)).contains(needle) { return true }

        return false
    }

    static func titleMatchesSearch(_ title: String, query: String) -> Bool {
        let needle = normalizedSearchText(query)
        guard !needle.isEmpty else { return false }
        return normalizedSearchText(title).contains(needle)
    }

    private static func normalizedSearchText(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func arrayItemTitle<Element>(
        element: Element,
        index: Int,
        key: String?
    ) -> String {
        guard let key,
              let raw = propertyValue(named: key, in: element),
              let title = displayTitle(raw),
              !title.isEmpty else {
            return "[\(index)]"
        }
        return title
    }

    private static func propertyValue(named key: String, in value: Any) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let current = mirror {
            for child in current.children where child.label == key {
                return child.value
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    private static func displayTitle(_ value: Any) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return displayTitle(child.value)
        }
        if let string = value as? String { return string }
        return String(describing: value).uncamelCased
    }

    @MainActor
    private static func wrapLeaf(_ view: AnyView, itemActions: SBJEditorItemActions?) -> AnyView {
        guard let itemActions else { return view }
        return AnyView(
            HStack(alignment: .center, spacing: 8) {
                itemActions.leadingView
                view
                itemActions.trailingView
            }
        )
    }

    @MainActor
    private static func castBinding<From, To>(
        _ binding: Binding<From>,
        to: To.Type
    ) -> Binding<To> {
        Binding<To>(
            get: { binding.wrappedValue as! To },
            set: { binding.wrappedValue = $0 as! From }
        )
    }
}

private struct SBJEditorFieldName: View {
    let text: String
    let isUnknown: Bool

    var body: some View {
        HStack(spacing: 5) {
            SBJEditorChangeIndicator()
            SBJEditorEmptyContentIndicator()
            if isUnknown {
                Text(text)
                    .fontWeight(.semibold)
                    .italic()
            } else {
                Text(text)
            }
        }
    }
}

private struct SBJSingleLineTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            TextField("", text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        if focusRequest?.claim() == true {
            isFocused = true
        }
    }
}

private struct SBJMultilineTextEditor: View {
    let label: String
    @Binding var value: String
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            TextEditor(text: $value)
                .focused($isFocused)
                .frame(minHeight: 84)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.secondary.opacity(0.35), lineWidth: 1)
                )
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        if focusRequest?.claim() == true {
            isFocused = true
        }
    }
}

private struct SBJIntegerEditor: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>?
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .overlay {
                    if let range, !range.contains(value) {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.red, lineWidth: 1)
                    }
                }
#if os(iOS)
                .keyboardType(.numbersAndPunctuation)
#endif
            if let range {
                Stepper("", value: $value, in: range)
                    .labelsHidden()
                    .fixedSize()
            }
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        if focusRequest?.claim() == true {
            isFocused = true
        }
    }
}

private struct SBJDoubleEditor: View {
    let label: String
    @Binding var value: Double
    let focusRequest: SBJEditorFocusRequest?
    let labelIsUnknown: Bool
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
        }
        .onAppear(perform: claimFocus)
    }

    private func claimFocus() {
        if focusRequest?.claim() == true {
            isFocused = true
        }
    }
}

private struct SBJOptionalEditor<Wrapped: Codable>: View {
    let label: String
    @Binding var value: Wrapped?
    let originalValue: Wrapped??
    let registry: SBJEditorRegistry
    let textStyle: SBJEditorTextStyle?
    let integerRange: ClosedRange<Int>?
    let arrayOrdering: Bool
    let arrayItemTitleKey: String?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    @State private var isExpanded = false
    @State private var pendingFocus: SBJEditorFocusRequest?
    @Environment(\.sbjEditorSearchQuery) private var searchQuery
    @Environment(\.sbjEditorShowChangedOnly) private var showChangedOnly
    @Environment(\.sbjEditorShowEmptyContentOnly) private var showEmptyContentOnly
    @Environment(\.sbjEditorHasContent) private var hasContent

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { isExpanded || !searchQuery.isEmpty || showChangedOnly || (showEmptyContentOnly && hasContent != false) },
            set: { newValue in
                if searchQuery.isEmpty && !showChangedOnly && !showEmptyContentOnly {
                    isExpanded = newValue
                }
            }
        )
    }

    var body: some View {
        if showEmptyContentOnly && hasContent == false {
            HStack(alignment: .center, spacing: 8) {
                if let itemActions {
                    itemActions.leadingView
                }
                if value != nil {
                    clearButton
                }
                SBJEditorFieldName(text: label, isUnknown: false)
                    .fontWeight((Wrapped.self as? any SBJEditable.Type) != nil ? .semibold : .regular)
                Spacer(minLength: 0)
                if let itemActions {
                    itemActions.trailingView
                }
            }
        } else if let unwrapped = Binding($value) {
            if let editable = Wrapped.self as? any SBJEditable.Type {
                if editable._sbjEditorFieldCount == 1 {
                    HStack(alignment: .center, spacing: 8) {
                        if let itemActions {
                            itemActions.leadingView
                        }
                        clearButton
                        editable._sbjMakeEditor(
                            label: label,
                            binding: SBJAnyBinding(unwrapped),
                            originalValue: originalWrapped.map { SBJEditorOriginalValue($0) },
                            registry: registry,
                            focusRequest: pendingFocus ?? focusRequest
                        )
                        if let itemActions {
                            itemActions.trailingView
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        SBJEditorDisclosureHeader(
                            label,
                            isExpanded: disclosureBinding,
                            leadingActions: AnyView(
                                HStack(spacing: 6) {
                                    if let itemActions {
                                        itemActions.leadingView
                                    }
                                    clearButton
                                }
                            ),
                            trailingActions: itemActions?.trailingView ?? AnyView(EmptyView())
                        )

                        if isExpanded || !searchQuery.isEmpty || showChangedOnly || showEmptyContentOnly {
                            let childSearchQuery = SBJValueEditor.titleMatchesSearch(label, query: searchQuery) ? "" : searchQuery
                            editable._sbjMakeEditorContents(
                                binding: SBJAnyBinding(unwrapped),
                                originalValue: originalWrapped.map { SBJEditorOriginalValue($0) },
                                registry: registry,
                                focusRequest: pendingFocus ?? focusRequest
                            )
                            .environment(\.sbjEditorSearchQuery, childSearchQuery)
                            .padding(.leading, 30)

                            Divider()
                        }
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 8) {
                    if let itemActions {
                        itemActions.leadingView
                    }
                    clearButton
                    SBJValueEditor.makeView(
                        label: label,
                        value: unwrapped,
                        originalValue: originalWrapped.map { SBJEditorOriginalValue($0) },
                        registry: registry,
                        textStyle: textStyle,
                        integerRange: integerRange,
                        arrayOrdering: arrayOrdering,
                        arrayItemTitleKey: arrayItemTitleKey,
                        focusRequest: pendingFocus ?? focusRequest
                    )
                    if let itemActions {
                        itemActions.trailingView
                    }
                }
            }
        } else {
            HStack(spacing: 8) {
                if let itemActions {
                    itemActions.leadingView
                }
                if Wrapped.self is any SBJEditable.Type {
                    Color.clear.frame(width: 22, height: 1)
                }
                Button {
                    value = registry.create(Wrapped.self)
                    if value != nil {
                        isExpanded = true
                        pendingFocus = SBJEditorFocusRequest()
                    }
                } label: {
                    Image(systemName: "circle.dashed")
                }
                .buttonStyle(.borderless)
                .disabled(registry.create(Wrapped.self) == nil)
                .accessibilityLabel("Set \(label)")
                SBJEditorFieldName(text: label, isUnknown: false)
                    .fontWeight((Wrapped.self as? any SBJEditable.Type) != nil ? .semibold : .regular)
                Spacer()
                if let itemActions {
                    itemActions.trailingView
                }
            }
        }
    }

    private var originalWrapped: Wrapped? {
        guard let originalValue else { return nil }
        return originalValue
    }

    private var clearButton: some View {
        Button {
            value = nil
            pendingFocus = nil
        } label: {
            Image(systemName: "xmark.circle")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Clear \(label)")
    }
}

private struct SBJArrayEditor<Element: Codable>: View {
    let label: String
    @Binding var value: [Element]
    let originalValue: [Element]?
    let registry: SBJEditorRegistry
    let textStyle: SBJEditorTextStyle?
    let integerRange: ClosedRange<Int>?
    let ordering: Bool
    let itemTitleKey: String?
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    @State private var isExpanded = false
    @State private var focusIndex: Int?
    @State private var pendingFocus: SBJEditorFocusRequest?
    @Environment(\.sbjEditorSearchQuery) private var searchQuery
    @Environment(\.sbjEditorShowChangedOnly) private var showChangedOnly
    @Environment(\.sbjEditorShowEmptyContentOnly) private var showEmptyContentOnly
    @Environment(\.sbjEditorHasContent) private var hasContent

    private var disclosureBinding: Binding<Bool> {
        Binding(
            get: { isExpanded || !searchQuery.isEmpty || showChangedOnly || (showEmptyContentOnly && hasContent != false) },
            set: { newValue in
                if searchQuery.isEmpty && !showChangedOnly && !showEmptyContentOnly {
                    isExpanded = newValue
                }
            }
        )
    }

    private var sortableType: (any SBJEditorSortable.Type)? {
        Element.self as? any SBJEditorSortable.Type
    }

    private var displayIndices: [Int] {
        let indices = Array(value.indices)
        let ordered: [Int]
        if !ordering, let sortableType {
            ordered = indices.sorted { lhsIndex, rhsIndex in
                let lhs = value[lhsIndex]
                let rhs = value[rhsIndex]
                if sortableType._sbjEditorLessThan(lhs, rhs) { return true }
                if sortableType._sbjEditorLessThan(rhs, lhs) { return false }
                return lhsIndex < rhsIndex
            }
        } else {
            ordered = indices
        }
        return ordered.filter { index in
            if showChangedOnly && !itemHasChanged(at: index) { return false }
            if showEmptyContentOnly && !SBJValueEditor.containsEmptyContent(value: value[index], registry: registry) {
                return false
            }
            guard !searchQuery.isEmpty else { return true }
            if SBJValueEditor.titleMatchesSearch(label, query: searchQuery) { return true }
            let title = itemTitle(for: value[index], index: index).text
            return SBJValueEditor.matchesSearch(
                label: title,
                value: value[index],
                query: searchQuery,
                registry: registry
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SBJEditorDisclosureHeader(
                "\(label) (\(value.count))",
                isExpanded: disclosureBinding,
                leadingActions: AnyView(
                    HStack(spacing: 6) {
                        if let itemActions {
                            itemActions.leadingView
                        }
                        Button {
                            if let newValue = registry.createArrayElement(Element.self, existing: value) {
                                value.append(newValue)
                                focusIndex = value.index(before: value.endIndex)
                                pendingFocus = SBJEditorFocusRequest()
                                isExpanded = true
                            }
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        .disabled(registry.createArrayElement(Element.self, existing: value) == nil)
                        .accessibilityLabel("Add \(label)")
                    }
                ),
                trailingActions: AnyView(
                    HStack(spacing: 6) {
                        if ordering, sortableType != nil {
                            Button(action: sortAscending) {
                                Image(systemName: "arrow.up.arrow.down.circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Sort \(label)")
                        }
                        if let itemActions {
                            itemActions.trailingView
                        }
                    }
                )
            )

            if isExpanded || !searchQuery.isEmpty || showChangedOnly || showEmptyContentOnly {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(displayIndices.enumerated()), id: \.element) { displayOffset, index in
                        let itemLabel = itemTitle(for: value[index], index: displayOffset)
                        let itemSearchQuery = SBJValueEditor.titleMatchesSearch(label, query: searchQuery) ? "" : searchQuery
                        let itemInvalid = SBJInvariantCheck.validationError(
                            value[index],
                            at: SBJValidationKeyPath(\Element.self)
                        ) != nil
                        SBJValueEditor.makeView(
                            label: itemLabel.text,
                            value: Binding(
                                get: { value[index] },
                                set: { value[index] = $0 }
                            ),
                            originalValue: originalElement(at: index).map { SBJEditorOriginalValue($0) },
                            registry: registry,
                            textStyle: textStyle,
                            integerRange: integerRange,
                            itemActions: actions(for: index),
                            focusRequest: index == focusIndex ? pendingFocus : focusRequest,
                            labelIsUnknown: itemLabel.isUnknown
                        )
                        .environment(\.sbjEditorSearchQuery, itemSearchQuery)
                        .environment(\.sbjEditorIsChanged, itemHasChanged(at: index))
                        .environment(\.sbjEditorHasContent, (value[index] as? any HasContentCheckable)?.hasContent)
                        .environment(\.sbjEditorIsInvalid, itemInvalid)
                        .sbjEditorValidationLineBackground(itemInvalid)
                    }
                }
                .padding(.leading, 30)
            }
        }
    }

    private func originalElement(at index: Int) -> Element? {
        guard let originalValue, originalValue.indices.contains(index) else { return nil }
        return originalValue[index]
    }

    private func itemHasChanged(at index: Int) -> Bool {
        guard value.indices.contains(index) else { return false }
        guard let original = originalElement(at: index) else { return true }
        return SBJEditorChangeComparison.isChanged(value[index], from: original)
    }

    private func itemTitle(for element: Element, index: Int) -> (text: String, isUnknown: Bool) {
        let prefix = "\(index + 1)) "
        guard let itemTitleKey,
              let raw = propertyValue(named: itemTitleKey, in: element),
              let title = displayTitle(raw),
              !title.isEmpty else {
            return (prefix + label, true)
        }
        return (prefix + title, false)
    }

    private func propertyValue(named key: String, in value: Any) -> Any? {
        var mirror: Mirror? = Mirror(reflecting: value)
        while let current = mirror {
            for child in current.children where child.label == key {
                return child.value
            }
            mirror = current.superclassMirror
        }
        return nil
    }

    private func displayTitle(_ value: Any) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return displayTitle(child.value)
        }
        if let string = value as? String {
            return string
        }
        return String(describing: value).uncamelCased
    }

    private func sortAscending() {
        guard let sortableType else { return }
        value = value.enumerated()
            .sorted { lhs, rhs in
                if sortableType._sbjEditorLessThan(lhs.element, rhs.element) { return true }
                if sortableType._sbjEditorLessThan(rhs.element, lhs.element) { return false }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
        focusIndex = nil
        pendingFocus = nil
    }

    @MainActor
    private func actions(for index: Int) -> SBJEditorItemActions {
        SBJEditorItemActions(
            remove: {
                guard value.indices.contains(index) else { return }
                value.remove(at: index)
                if focusIndex == index {
                    focusIndex = nil
                    pendingFocus = nil
                } else if let focusIndex, focusIndex > index {
                    self.focusIndex = focusIndex - 1
                }
            },
            moveUp: ordering && index > value.startIndex ? {
                guard value.indices.contains(index), value.indices.contains(index - 1) else { return }
                value.swapAt(index, index - 1)
            } : nil,
            moveDown: ordering && value.indices.contains(index + 1) ? {
                guard value.indices.contains(index), value.indices.contains(index + 1) else { return }
                value.swapAt(index, index + 1)
            } : nil
        )
    }
}

private struct SBJBooleanEditor: View {
    let label: String
    @Binding var value: Bool
    let labelIsUnknown: Bool

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            Toggle("", isOn: $value)
                .labelsHidden()
                .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

private struct SBJEnumEditor<Value: SBJEditableEnum>: View {
    let label: String
    @Binding var value: Value
    let labelIsUnknown: Bool

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            Picker("", selection: $value) {
                ForEach(Array(Value.allCases), id: \.self) { option in
                    Text(option.sbjEditorCaseName).tag(option)
                }
            }
            .labelsHidden()
#if os(iOS)
            .pickerStyle(.menu)
#endif
            .fixedSize()
            Spacer(minLength: 0)
        }
    }
}

private struct SBJUnsupportedEditor<Value>: View {
    let label: String
    let type: Value.Type
    let value: Value
    let labelIsUnknown: Bool
    @Environment(\.sbjEditorShowIssues) private var showIssues

    var body: some View {
        HStack(spacing: 8) {
            SBJEditorFieldName(text: label, isUnknown: labelIsUnknown)
            if let description = SBJEditorValueDescription.describe(value) {
                Text(description)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(action: showIssues) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Show unsupported editor properties")
        }
    }
}
