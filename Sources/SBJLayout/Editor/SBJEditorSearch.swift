import SwiftUI

private struct SBJEditorSearchQueryKey: EnvironmentKey {
    static let defaultValue = ""
}

extension EnvironmentValues {
    var sbjEditorSearchQuery: String {
        get { self[SBJEditorSearchQueryKey.self] }
        set { self[SBJEditorSearchQueryKey.self] = newValue }
    }
}

@MainActor
struct SBJEditorSearchBar: View {
    @Binding var text: String
    @Binding var showChangedOnly: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search editor", text: $text)
                .textFieldStyle(.roundedBorder)
            Button {
                showChangedOnly.toggle()
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(showChangedOnly ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showChangedOnly ? "Show all values" : "Show changed values only")

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear search")
            }
        }
    }
}
