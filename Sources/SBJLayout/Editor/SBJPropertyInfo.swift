import Foundation

/// Supplemental information about a property presented by the generated editor.
///
/// This is intentionally opt-in. Most properties do not need explanatory
/// metadata; clients should use it for behavior, provenance, lifecycle, or other
/// details that are not obvious from the field's name and ordinary domain
/// knowledge.
public struct SBJPropertyInfo: Sendable, Equatable {
    public let title: String?
    public let summary: String
    public let details: String
    public let accessibilityLabel: String?
    public let accessibilityHint: String?

    public init(
        title: String? = nil,
        summary: String,
        details: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil
    ) {
        self.title = title
        self.summary = summary
        self.details = details
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityHint = accessibilityHint
    }
}
