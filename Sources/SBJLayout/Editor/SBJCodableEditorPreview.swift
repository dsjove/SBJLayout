#if DEBUG
import SwiftUI

private enum SBJEditorPreviewChoice: String, SBJEditableEnum {
    case firstChoice
    case secondChoice
    case thirdChoice
}

@CodableEditor
private enum SBJEditorPreviewAssociatedEnum: Codable {
    case automatic
    case adjusted(amount: Int, enabled: Bool)
    case fixed(Int)
}

private struct SBJEditorPreviewCustom: Codable, Equatable {
    var value: String
}

@CodableEditor
private struct SBJEditorPreviewSingle: Codable {
    var amount: Int
}

@CodableEditor
private struct SBJEditorPreviewNested: Codable {
    var title: String
    var enabled: Bool
    var single: SBJEditorPreviewSingle
}

@CodableEditor
private struct SBJEditorPreviewItem: Codable, SBJEditorCreatable, SBJEditorSortable {
    var name: String
    var quantity: Int
    var note: String?

    static func sbjCreateEditorValue() -> Self {
        .init(name: "New Item", quantity: 1, note: nil)
    }

    static func sbjEditorLessThan(_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}

@CodableEditor
private struct SBJEditorPreviewModel: Codable {
    var name = "Preview"

    @EditorText(.multiline)
    var notes = "Multiline text\nshows the text editor."

    @EditorInteger(range: 0...20)
    var count = 3
    var ratio = 1.5
    var enabled = true
    var choice: SBJEditorPreviewChoice = .secondChoice
    var nested = SBJEditorPreviewNested(title: "Nested", enabled: true, single: .init(amount: 7))
    var optionalText: String? = "Optional value"
    var nilText: String?

    @EditorArray(title: "name")
    var orderedItems = [
        SBJEditorPreviewItem(name: "Beta", quantity: 2, note: nil),
        SBJEditorPreviewItem(name: "Alpha", quantity: 1, note: "Optional note")
    ]

    @EditorArray(ordering: false, title: "name")
    var sortedItems = [
        SBJEditorPreviewItem(name: "Zulu", quantity: 1, note: nil),
        SBJEditorPreviewItem(name: "Echo", quantity: 1, note: nil)
    ]

    var custom = SBJEditorPreviewCustom(value: "Registered custom editor")
    var associatedEnum: SBJEditorPreviewAssociatedEnum = .adjusted(amount: 12, enabled: true)

    @NotEditable
    let immutableIdentifier = "not shown"
}

@MainActor
private struct SBJCodableEditorPreviewHost: View {
    @State private var value = SBJEditorPreviewModel()

    private var registry: SBJEditorRegistry {
        var registry = SBJEditorRegistry()
        registry.register(SBJEditorPreviewCustom.self) { label, binding, _ in
            HStack(spacing: 8) {
                Text(label)
                TextField("", text: Binding(
                    get: { binding.wrappedValue.value },
                    set: { binding.wrappedValue.value = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
        return registry
    }

    var body: some View {
        Form {
            SBJCodableEditorCore(value: $value, registry: registry)
        }
    }
}

#Preview("Codable Editor Core") {
    SBJCodableEditorPreviewHost()
        .frame(minWidth: 700, minHeight: 900)
}
#endif
