import SwiftUI

private struct SBJEditorShowChangedOnlyKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SBJEditorIsChangedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var sbjEditorShowChangedOnly: Bool {
        get { self[SBJEditorShowChangedOnlyKey.self] }
        set { self[SBJEditorShowChangedOnlyKey.self] = newValue }
    }

    var sbjEditorIsChanged: Bool {
        get { self[SBJEditorIsChangedKey.self] }
        set { self[SBJEditorIsChangedKey.self] = newValue }
    }
}


struct SBJEditorOriginalValue {
    let storage: Any

    init<Value>(_ value: Value) {
        self.storage = value as Any
    }

    func value<Value>(as type: Value.Type = Value.self) -> Value {
        storage as! Value
    }
}

enum SBJEditorChangeComparison {
    static func isChanged<Value: Encodable>(_ value: Value, from original: Value?) -> Bool {
        guard let original else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let lhs = try? encoder.encode(value),
              let rhs = try? encoder.encode(original) else {
            return String(describing: value) != String(describing: original)
        }
        return lhs != rhs
    }

    static func snapshot<Value: Codable>(_ value: Value) -> Value {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(value),
              let copy = try? decoder.decode(Value.self, from: data) else {
            return value
        }
        return copy
    }
}

struct SBJEditorChangeIndicator: View {
    @Environment(\.sbjEditorIsChanged) private var isChanged

    var body: some View {
        if isChanged {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
        }
    }
}

// TODO: Add native editor support for Set. Sets need uniqueness-safe replacement semantics
// and deterministic display ordering; they should not be treated as reorderable arrays.
// TODO: Add native editor support for Dictionary. Dictionary keys are editable data, not
// structural identity; key edits must safely reject collisions while preserving values.
// TODO: Consider native support for additional common Codable containers/value types as
// they appear in client models, especially Date, Data, URL, UUID, and RawRepresentable
// value wrappers that are not already covered by enum/custom-editor support.
