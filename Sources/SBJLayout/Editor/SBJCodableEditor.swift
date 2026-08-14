import SwiftUI

/// Reusable editor body for values annotated with ``CodableEditor()``.
///
/// This view owns only editor behavior. Application navigation, presentation,
/// restore/done buttons, and other window/sheet chrome belong outside it.
public struct SBJCodableEditorCore<Value: SBJEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry
    @State private var isShowingIssues = false
    @State private var searchText = ""
    @State private var effectiveSearchText = ""
    @State private var showChangedOnly = false
    @State private var showEmptyContentOnly = false
    @State private var originalValue: Value

    public init(
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.registry = registry
        self._originalValue = State(initialValue: SBJEditorChangeComparison.snapshot(value.wrappedValue))
    }

    private var issues: [SBJEditorIssue] {
        SBJEditorDiagnostics.issues(for: value, registry: registry)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SBJEditorSearchBar(
                text: $searchText,
                showChangedOnly: $showChangedOnly,
                showEmptyContentOnly: $showEmptyContentOnly,
                hasIssues: !issues.isEmpty,
                showIssues: { isShowingIssues = true }
            )

            ForEach(Array(Value.sbjEditorFields.enumerated()), id: \.offset) { _, field in
                field.view(root: $value, originalRoot: originalValue, registry: registry)
            }
        }
        .environment(\.sbjEditorSearchQuery, effectiveSearchText)
        .task(id: searchText) {
            if searchText.isEmpty {
                effectiveSearchText = ""
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            effectiveSearchText = searchText
        }
        .environment(\.sbjEditorShowChangedOnly, showChangedOnly)
        .environment(\.sbjEditorShowEmptyContentOnly, showEmptyContentOnly)
        .environment(\.sbjEditorShowIssues, {
            isShowingIssues = true
        })
        .sheet(isPresented: $isShowingIssues) {
            SBJEditorIssueList(issues: issues)
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }
}

/// Compatibility wrapper around ``SBJCodableEditorCore``.
///
/// Existing clients can keep using `SBJCodableEditor`; new code that wants to
/// make the editor/shell separation explicit can use `SBJCodableEditorCore`.
public struct SBJCodableEditor<Value: SBJEditable>: View {
    @Binding private var value: Value
    private let registry: SBJEditorRegistry

    public init(
        _ title: String? = nil,
        value: Binding<Value>,
        registry: SBJEditorRegistry = .init()
    ) {
        self._value = value
        self.registry = registry
    }

    public var body: some View {
        SBJCodableEditorCore(value: $value, registry: registry)
    }
}

struct SBJObjectEditor<Value: SBJEditable>: View {
    let title: String
    @Binding var value: Value
    let originalValue: Value?
    let registry: SBJEditorRegistry
    let itemActions: SBJEditorItemActions?
    let focusRequest: SBJEditorFocusRequest?
    let titleIsUnknown: Bool
    @State private var isExpanded = false
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
        Group {
            if showEmptyContentOnly && hasContent == false {
                HStack(alignment: .center, spacing: 8) {
                    if let itemActions {
                        itemActions.leadingView
                    }
                    SBJEditorChangeIndicator()
                    SBJEditorEmptyContentIndicator()
                    if titleIsUnknown {
                        Text(title).fontWeight(.semibold).italic()
                    } else {
                        Text(title).fontWeight(.semibold)
                    }
                    Spacer(minLength: 0)
                    if let itemActions {
                        itemActions.trailingView
                    }
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if Value.sbjEditorFields.count == 1, let field = Value.sbjEditorFields.first {
                HStack(alignment: .center, spacing: 8) {
                    if let itemActions {
                        itemActions.leadingView
                    }
                    field.view(
                        root: $value,
                        originalRoot: originalValue,
                        registry: registry,
                        nameOverride: "\(title) • \(field.name)",
                        focusRequest: focusRequest,
                        labelIsUnknown: titleIsUnknown
                    )
                    if let itemActions {
                        itemActions.trailingView
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    SBJEditorDisclosureHeader(
                        title,
                        isExpanded: disclosureBinding,
                        leadingActions: itemActions?.leadingView ?? AnyView(EmptyView()),
                        trailingActions: itemActions?.trailingView ?? AnyView(EmptyView()),
                        titleIsUnknown: titleIsUnknown
                    )

                    if isExpanded || !searchQuery.isEmpty || showChangedOnly || showEmptyContentOnly {
                        let childSearchQuery = SBJValueEditor.titleMatchesSearch(title, query: searchQuery) ? "" : searchQuery
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(Value.sbjEditorFields.enumerated()), id: \.offset) { _, field in
                                field.view(root: $value, originalRoot: originalValue, registry: registry, focusRequest: focusRequest)
                            }
                        }
                        .environment(\.sbjEditorSearchQuery, childSearchQuery)
                        .padding(.leading, 30)

                        Divider()
                    }
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        .onAppear {
            if focusRequest != nil {
                isExpanded = true
            }
        }
    }
}
