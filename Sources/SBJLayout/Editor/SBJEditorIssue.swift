import SwiftUI

/// One property for which the generic editor has no registered/built-in editor.
public struct SBJEditorIssue: Identifiable, Hashable {
    public enum Kind: Hashable { case unsupported, validation }

    public let kind: Kind
    public let path: String
    public let typeName: String
    public let valueDescription: String?

    public var id: String { "\(path)|\(typeName)" }

    public init(path: String, typeName: String, valueDescription: String?, kind: Kind = .unsupported) {
        self.kind = kind
        self.path = path
        self.typeName = typeName
        self.valueDescription = valueDescription
    }

    public static func validation(path: String, message: String) -> Self {
        .init(path: path, typeName: "Validation", valueDescription: message, kind: .validation)
    }
}

private struct SBJEditorShowIssuesKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    var sbjEditorShowIssues: @MainActor () -> Void {
        get { self[SBJEditorShowIssuesKey.self] }
        set { self[SBJEditorShowIssuesKey.self] = newValue }
    }
}

enum SBJEditorValueDescription {
    static func describe(_ value: Any) -> String? {
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else { return nil }
            return describe(child.value)
        }

        if let described = value as? any CustomStringConvertible {
            let text = described.description.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        switch mirror.displayStyle {
        case .enum:
            let text = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        default:
            return nil
        }
    }
}

public struct SBJEditorIssueList: View {
    public let issues: [SBJEditorIssue]

    public init(issues: [SBJEditorIssue]) {
        self.issues = issues
    }
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(issues) { issue in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(issue.path)
                                .fontWeight(.semibold)
                            Text(issue.typeName)
                                .foregroundStyle(.secondary)
                            if let valueDescription = issue.valueDescription {
                                Text(valueDescription)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if issue.id != issues.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Editor Issues")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}


/// Public recursive diagnostics for values presented by the Codable editor.
public enum SBJEditorDiagnostics {
    @MainActor
    public static func issues<Value: SBJEditable>(
        for value: Value,
        registry: SBJEditorRegistry = .init()
    ) -> [SBJEditorIssue] {
        let all = Value.sbjEditorFields.flatMap { field in
            field.issues(root: value, path: [], registry: registry)
        }
        var seen = Set<String>()
        return all.filter { issue in
            let key = "\(issue.kind)|\(issue.path)|\(issue.valueDescription ?? "")"
            return seen.insert(key).inserted
        }
    }
}
