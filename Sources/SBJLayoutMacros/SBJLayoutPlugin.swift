import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SBJLayoutPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableEditorMacro.self,
        NotEditableMacro.self,
        EditorTextMacro.self,
        EditorIntegerMacro.self,
        EditorNumberMacro.self,
        EditorOptionalMacro.self,
        EditorArrayMacro.self,
    ]
}
