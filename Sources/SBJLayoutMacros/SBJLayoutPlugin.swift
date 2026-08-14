import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJLayoutPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableEditorMacro.self,
        NotEditableMacro.self,
        EditorTextMacro.self,
        EditorIntegerMacro.self,
        EditorArrayMacro.self,
    ]
}
