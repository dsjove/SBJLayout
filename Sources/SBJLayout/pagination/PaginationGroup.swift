import Foundation

/// A declarative pagination scope, not a layout element.
///
/// A group allows a page break before its first unit. `.page` requires one,
/// `.keepWith` joins its first unit to preceding content (Keep With Above),
/// and `.flow` (the default) permits a break when necessary. Nested scopes
/// contribute additional legal boundaries without remeasuring their parent.
public struct PaginationGroup {
    let id: UUID
    public let sectionID: String?
    public let behavior: PaginationBehavior
    public let content: Renderables

    public init(
        sectionID: String? = nil,
        behavior: PaginationBehavior = .flow,
        @RenderableBuilder content: () -> Renderables
    ) {
        self.id = UUID()
        self.sectionID = sectionID
        self.behavior = behavior
        self.content = content()
    }
}

public enum PaginationBehavior: String, Codable, CaseIterable, Sendable {
    case page, keepWith, flow

    public var displayName: String {
        switch self {
        case .page: "Page Break"
        case .keepWith: "Keep With Above"
        case .flow: "Flow"
        }
    }
}
