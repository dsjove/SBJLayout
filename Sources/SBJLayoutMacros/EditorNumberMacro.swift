import SwiftSyntax
import SwiftSyntaxMacros

/// Marker consumed by `CodableEditorMacro`. It intentionally emits no peer.
public struct EditorNumberMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] { [] }
}
