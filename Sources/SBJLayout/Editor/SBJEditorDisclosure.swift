import SwiftUI

/// Shared disclosure row used by the generated editor.
///
/// The disclosure control occupies a stable leading column. Additional row
/// controls (add/remove/clear) appear immediately after it. Reordering controls
/// may be supplied at the trailing edge. The title area fills the remaining row
/// and toggles disclosure when tapped.
struct SBJEditorDisclosureHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let leadingActions: AnyView
    let trailingActions: AnyView
    let titleIsUnknown: Bool

    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        leadingActions: AnyView = AnyView(EmptyView()),
        trailingActions: AnyView = AnyView(EmptyView()),
        titleIsUnknown: Bool = false
    ) {
        self.title = title
        self._isExpanded = isExpanded
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
        self.titleIsUnknown = titleIsUnknown
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(.secondary.opacity(0.55), lineWidth: 1)
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")

            leadingActions

            SBJEditorChangeIndicator()
            SBJEditorEmptyContentIndicator()

            Button(action: toggle) {
                HStack(spacing: 8) {
                    if titleIsUnknown {
                        Text(title)
                            .fontWeight(.semibold)
                            .italic()
                    } else {
                        Text(title)
                            .fontWeight(.semibold)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            trailingActions
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private func toggle() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isExpanded.toggle()
        }
    }
}
