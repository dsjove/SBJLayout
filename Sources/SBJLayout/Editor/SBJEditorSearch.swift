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
    @Binding var showEmptyContentOnly: Bool
    let hasIssues: Bool
    let showIssues: () -> Void

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
                    .foregroundStyle(showChangedOnly ? Color.white : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background {
                        if showChangedOnly {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        }
                    }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showChangedOnly ? "Show all values" : "Show changed values only")

            Button {
                showEmptyContentOnly.toggle()
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(showEmptyContentOnly ? Color.white : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background {
                        if showEmptyContentOnly {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor)
                        }
                    }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(showEmptyContentOnly ? "Show all values" : "Show values with no content only")


            if hasIssues {
                Button(action: showIssues) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Show editor issues")
            }
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
