import SwiftUI

/// A value whose stored properties can be presented by ``SBJCodableEditor``.
///
/// Normally this conformance is synthesized by ``CodableEditor()``.
public protocol SBJEditable: Codable, HasContentCheckable {

    @MainActor
    static var sbjEditorFields: [SBJEditorField<Self>] { get }
}

public extension SBJEditable {
    /// Type-erased field count used by the recursive editor when it only has
    /// an `any SBJEditable.Type`. Unlike `sbjEditorFields`, this does not expose
    /// `Self` in its result type, so it is safe to call through the existential.
    @MainActor
    internal static var _sbjEditorFieldCount: Int {
        Self.sbjEditorFields.count
    }

    @MainActor
    internal static func _sbjContainsEmptyContent(
        value: Any,
        registry: SBJEditorRegistry
    ) -> Bool {
        guard let typed = value as? Self else { return false }
        if !typed.hasContent { return true }
        return Self.sbjEditorFields.contains { field in
            field.containsEmptyContent(root: typed, registry: registry)
        }
    }

    @MainActor
    internal static func _sbjCollectIssues(
        value: Any,
        path: [String],
        registry: SBJEditorRegistry
    ) -> [SBJEditorIssue] {
        guard let typed = value as? Self else { return [] }
        return Self.sbjEditorFields.flatMap { field in
            field.issues(root: typed, path: path, registry: registry)
        }
    }

    /// Human-readable default name used for nested disclosure groups.
    static var sbjEditorTypeName: String {
        String(describing: Self.self).uncamelCased
    }

    @MainActor
    internal static func _sbjMakeEditor(
        label: String,
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        itemActions: SBJEditorItemActions? = nil,
        focusRequest: SBJEditorFocusRequest? = nil,
        titleIsUnknown: Bool = false
    ) -> AnyView {
        let typedBinding = Binding<Self>(
            get: { binding.get() as! Self },
            set: { binding.set($0) }
        )

        return AnyView(
            SBJObjectEditor(
                title: label,
                value: typedBinding,
                originalValue: originalValue.map { $0.value(as: Self.self) },
                registry: registry,
                itemActions: itemActions,
                focusRequest: focusRequest,
                titleIsUnknown: titleIsUnknown
            )
        )
    }
    @MainActor
    internal static func _sbjMakeEditorContents(
        binding: SBJAnyBinding,
        originalValue: SBJEditorOriginalValue? = nil,
        registry: SBJEditorRegistry,
        focusRequest: SBJEditorFocusRequest? = nil
    ) -> AnyView {
        let typedBinding = Binding<Self>(
            get: { binding.get() as! Self },
            set: { binding.set($0) }
        )
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Self.sbjEditorFields.enumerated()), id: \.offset) { _, field in
                    field.view(root: typedBinding, originalRoot: originalValue.map { $0.value(as: Self.self) }, registry: registry, focusRequest: focusRequest)
                }
            }
        )
    }

}

/// Optional protocol for types that can manufacture a sensible new value.
/// Arrays and nil optionals use this when the user taps their add control.
public protocol SBJEditorCreatable {
    static func sbjCreateEditorValue() -> Self
}

/// Optional creation hook for arrays whose new value depends on the values
/// already present (for example a keyed collection of ability scores).
public protocol SBJEditorArrayCreatable {
    static func sbjCreateEditorValue(existing: [Self]) -> Self?
}

public extension SBJEditorArrayCreatable {
    static func _sbjCreateEditorValue(existing: [Any]) -> Any? {
        sbjCreateEditorValue(existing: existing.compactMap { $0 as? Self })
    }
}



/// Optional ordering hook for array element types whose values have a natural
/// editor sort order. Arrays opt into reordering independently; this protocol
/// only defines how two elements compare.
public protocol SBJEditorSortable {
    static func sbjEditorLessThan(_ lhs: Self, _ rhs: Self) -> Bool
}

public extension SBJEditorSortable {
    static func _sbjEditorLessThan(_ lhs: Any, _ rhs: Any) -> Bool {
        guard let lhs = lhs as? Self, let rhs = rhs as? Self else { return false }
        return sbjEditorLessThan(lhs, rhs)
    }
}

/// Opt-in support for enums that should be rendered as a menu/picker.
///
/// The default label is derived from the case's textual representation, so
/// `lawfulGood` becomes `Lawful Good`. The first declared case is also used
/// as the default when creating a previously-nil optional enum.
public protocol SBJEditableEnum: Codable, CaseIterable, Hashable, SBJEditorCreatable {
    var sbjEditorCaseName: String { get }
}

public extension SBJEditableEnum {
    var sbjEditorCaseName: String {
        String(describing: self).uncamelCased
    }

    static func sbjCreateEditorValue() -> Self {
        guard let first = allCases.first else {
            preconditionFailure("SBJEditableEnum requires at least one case")
        }
        return first
    }
}
