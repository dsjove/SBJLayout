import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodableEditorMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return structMembers(for: structDecl, in: context)
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return enumMembers(for: enumDecl, in: context)
        }
        throw CodableEditorMacroError.onlyStructsOrEnums
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let conformance: String
        if declaration.is(StructDeclSyntax.self) {
            conformance = "SBJEditable"
        } else if declaration.is(EnumDeclSyntax.self) {
            conformance = "SBJEditableAssociatedEnum"
        } else {
            throw CodableEditorMacroError.onlyStructsOrEnums
        }

        let extensionDecl: DeclSyntax = """
        extension \(type.trimmed): \(raw: conformance) {}
        """
        return [extensionDecl.cast(ExtensionDeclSyntax.self)]
    }

    // MARK: - Structs

    private static func structMembers(
        for structDecl: StructDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let codedNames = codingKeyNames(in: structDecl)
        let access = effectiveAccessPrefix(modifiers: structDecl.modifiers, in: context)

        var entries: [String] = []

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) else {
                continue
            }
            guard !hasAttribute(named: "NotEditable", on: variable) else { continue }

            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let name = identifier.identifier.text

                guard binding.accessorBlock == nil else { continue }
                if let codedNames, !codedNames.contains(name) { continue }

                if variable.bindingSpecifier.tokenKind == .keyword(.let) {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(identifier.identifier),
                            message: ImmutableEditorPropertyWarning(name: name)
                        )
                    )
                    continue
                }

                let textStyle = editorTextStyle(on: variable)
                let textStyleArgument = textStyle.map { ", textStyle: \($0)" } ?? ""
                let integerRange = editorIntegerRange(on: variable)
                let integerRangeArgument = integerRange.map { ", integerRange: \($0)" } ?? ""
                let arrayOptions = editorArrayOptions(on: variable)
                let arrayOrderingArgument = arrayOptions.ordering.map { ", arrayOrdering: \($0)" } ?? ""
                let arrayTitleArgument = arrayOptions.title.map { ", arrayItemTitleKey: \"\($0)\"" } ?? ""
                entries.append(
                    "SBJEditorField<Self>(name: SBJEditorLabel.humanize(\"\(name)\"), \\.\(name)\(textStyleArgument)\(integerRangeArgument)\(arrayOrderingArgument)\(arrayTitleArgument))"
                )
            }
        }

        let body = entries.joined(separator: ",\n            ")
        return [
            DeclSyntax(stringLiteral: """
            @MainActor
            \(access)static var sbjEditorFields: [SBJEditorField<Self>] {
                [
                    \(body)
                ]
            }
            """)
        ]
    }

    // MARK: - Associated-value enums

    private struct EnumParameter {
        let type: String
        let fieldName: String
        let constructorLabel: String?
        let variableName: String
    }

    private struct EnumCaseInfo {
        let caseName: String
        let displayName: String
        let parameters: [EnumParameter]
    }

    private static func enumMembers(
        for enumDecl: EnumDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        let access = effectiveAccessPrefix(modifiers: enumDecl.modifiers, in: context)
        let cases = enumCases(in: enumDecl)

        let caseEntries = cases.map(enumCaseDescriptor).joined(separator: ",\n            ")
        let failableCreatorBody = enumFailableCreatorBody(for: cases)

        return [
            DeclSyntax(stringLiteral: """
            @MainActor
            \(access)static var sbjEditorEnumCases: [SBJEditorEnumCase<Self>] {
                [
                    \(caseEntries)
                ]
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static func sbjCreateEditorValueIfPossible() -> Self? {
                \(failableCreatorBody)
            }
            """),
            DeclSyntax(stringLiteral: """
            \(access)static func sbjCreateEditorValue() -> Self {
                guard let value = sbjCreateEditorValueIfPossible() else {
                    preconditionFailure("No enum case has creatable associated values")
                }
                return value
            }
            """)
        ]
    }

    private static func enumCases(in declaration: EnumDeclSyntax) -> [EnumCaseInfo] {
        var result: [EnumCaseInfo] = []
        for member in declaration.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                let parametersSyntax = element.parameterClause.map { Array($0.parameters) } ?? []
                let count = parametersSyntax.count
                let parameters = parametersSyntax.enumerated().map { offset, parameter in
                    let firstName = parameter.firstName?.text
                    let secondName = parameter.secondName?.text
                    let constructorLabel: String?
                    if let firstName, firstName != "_" {
                        constructorLabel = firstName
                    } else {
                        constructorLabel = nil
                    }

                    let semanticName: String?
                    if let secondName, secondName != "_" {
                        semanticName = secondName
                    } else if let firstName, firstName != "_" {
                        semanticName = firstName
                    } else {
                        semanticName = nil
                    }

                    let fieldName: String
                    if let semanticName {
                        fieldName = humanize(semanticName)
                    } else if count == 1 {
                        fieldName = "Value"
                    } else {
                        fieldName = "Value \(offset + 1)"
                    }

                    return EnumParameter(
                        type: parameter.type.trimmedDescription,
                        fieldName: fieldName,
                        constructorLabel: constructorLabel,
                        variableName: "_sbjValue\(offset)"
                    )
                }
                result.append(
                    EnumCaseInfo(
                        caseName: caseName,
                        displayName: humanize(caseName),
                        parameters: parameters
                    )
                )
            }
        }
        return result
    }

    private static func enumCaseDescriptor(_ info: EnumCaseInfo) -> String {
        let pattern = casePattern(info)
        let defaultBody = enumOptionalCreatorBody(for: info)
        let associated = info.parameters.enumerated().map { index, parameter in
            enumAssociatedValueDescriptor(info: info, parameterIndex: index, parameter: parameter)
        }.joined(separator: ",\n                    ")

        return """
        SBJEditorEnumCase<Self>(
            name: \"\(info.displayName)\",
            matches: { value in
                if case \(pattern) = value { return true }
                return false
            },
            makeDefault: {
                \(defaultBody)
            },
            associatedValues: [
                \(associated)
            ]
        )
        """
    }

    private static func enumAssociatedValueDescriptor(
        info: EnumCaseInfo,
        parameterIndex: Int,
        parameter: EnumParameter
    ) -> String {
        let getPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? candidate.variableName : "_"
        }
        let getPattern = caseLetPattern(info, names: getPatternNames)

        let setterPatternNames = info.parameters.enumerated().map { index, candidate in
            index == parameterIndex ? "_" : candidate.variableName
        }
        let setterPattern = caseLetPattern(info, names: setterPatternNames)
        let setterCaseKeyword = setterPatternNames.contains(where: { $0 != "_" }) ? "case let" : "case"

        var replacementNames = info.parameters.map(\.variableName)
        replacementNames[parameterIndex] = "newValue"
        let reconstruction = caseConstruction(info, values: replacementNames)

        return """
        SBJEditorAssociatedValue<Self>(
            name: "\(parameter.fieldName)",
            get: { root in
                guard case let \(getPattern) = root else {
                    preconditionFailure("Associated value accessed while enum is in a different case")
                }
                return \(parameter.variableName)
            },
            set: { root, newValue in
                guard \(setterCaseKeyword) \(setterPattern) = root else { return }
                root = \(reconstruction)
            }
        )
        """
    }

    private static func enumOptionalCreatorBody(for info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else { return "return .\(info.caseName)" }
        let guards = info.parameters.map { parameter in
            "guard let \(parameter.variableName) = SBJEditorDefaultValue.value(for: \(parameter.type).self) else { return nil }"
        }.joined(separator: "\n                ")
        return """
        \(guards)
                return \(caseConstruction(info, values: info.parameters.map(\.variableName)))
        """
    }

    private static func enumFailableCreatorBody(for cases: [EnumCaseInfo]) -> String {
        guard !cases.isEmpty else { return "return nil" }
        let attempts = cases.map { info in
            let caseBody = enumOptionalCreatorBody(for: info)
            return """
            if let value: Self = ({ () -> Self? in
                \(caseBody)
            })() {
                return value
            }
            """
        }.joined(separator: "\n        ")
        return """
        \(attempts)
        return nil
        """
    }

    private static func casePattern(_ info: EnumCaseInfo) -> String {
        guard !info.parameters.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(Array(repeating: "_", count: info.parameters.count).joined(separator: ", ")))"
    }

    private static func caseLetPattern(_ info: EnumCaseInfo, names: [String]) -> String {
        guard !names.isEmpty else { return ".\(info.caseName)" }
        return ".\(info.caseName)(\(names.joined(separator: ", ")))"
    }

    private static func caseConstruction(_ info: EnumCaseInfo, values: [String]) -> String {
        guard !values.isEmpty else { return ".\(info.caseName)" }
        let arguments = zip(info.parameters, values).map { parameter, value in
            if let label = parameter.constructorLabel {
                return "\(label): \(value)"
            }
            return value
        }.joined(separator: ", ")
        return ".\(info.caseName)(\(arguments))"
    }

    // MARK: - Shared metadata helpers

    private static func effectiveAccessPrefix(
        modifiers: DeclModifierListSyntax,
        in context: some MacroExpansionContext
    ) -> String {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.open):
                return "public "
            case .keyword(.private), .keyword(.fileprivate), .keyword(.internal), .keyword(.package):
                return ""
            default:
                continue
            }
        }

        for syntax in context.lexicalContext {
            guard let extensionDecl = syntax.as(ExtensionDeclSyntax.self) else { continue }
            if extensionDecl.modifiers.contains(where: { modifier in
                modifier.name.tokenKind == .keyword(.public) ||
                modifier.name.tokenKind == .keyword(.open)
            }) {
                return "public "
            }
        }

        return ""
    }

    private static func humanize(_ value: String) -> String {
        guard !value.isEmpty else { return value }
        var output = ""
        var previousWasLowerOrDigit = false
        for character in value {
            if character == "_" {
                if !output.hasSuffix(" ") { output.append(" ") }
                previousWasLowerOrDigit = false
                continue
            }
            let isUpper = character.isUppercase
            if isUpper && previousWasLowerOrDigit && !output.hasSuffix(" ") {
                output.append(" ")
            }
            output.append(character)
            previousWasLowerOrDigit = character.isLowercase || character.isNumber
        }
        return output
            .split(separator: " ")
            .map { word in
                guard let first = word.first else { return "" }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }

    private static func editorTextStyle(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorText" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments,
                  let argument = arguments.first else {
                return nil
            }

            switch argument.expression.trimmedDescription {
            case ".multiline", "SBJEditorTextStyle.multiline":
                return ".multiline"
            case ".singleLine", "SBJEditorTextStyle.singleLine":
                return ".singleLine"
            default:
                return nil
            }
        }
        return nil
    }


    private static func editorIntegerRange(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorInteger" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return nil
            }
            for argument in arguments where argument.label?.text == "range" {
                return argument.expression.trimmedDescription
            }
        }
        return nil
    }

    private static func editorArrayOptions(on variable: VariableDeclSyntax) -> (ordering: String?, title: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorArray" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return ("true", nil)
            }

            var ordering: String? = "true"
            var title: String?
            for argument in arguments {
                switch argument.label?.text {
                case "ordering":
                    switch argument.expression.trimmedDescription {
                    case "false": ordering = "false"
                    case "true": ordering = "true"
                    default: ordering = nil
                    }
                case "title":
                    let expression = argument.expression.trimmedDescription
                    if expression == "nil" {
                        title = nil
                    } else if expression.hasPrefix("\"") && expression.hasSuffix("\"") {
                        title = String(expression.dropFirst().dropLast())
                    }
                default:
                    continue
                }
            }
            return (ordering, title)
        }
        return (nil, nil)
    }

    private static func hasAttribute(named name: String, on variable: VariableDeclSyntax) -> Bool {
        variable.attributes.contains { element in
            guard case .attribute(let attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == name
        }
    }

    private static func codingKeyNames(in declaration: StructDeclSyntax) -> Set<String>? {
        for member in declaration.memberBlock.members {
            guard let enumDecl = member.decl.as(EnumDeclSyntax.self),
                  enumDecl.name.text == "CodingKeys" else { continue }

            var names = Set<String>()
            for enumMember in enumDecl.memberBlock.members {
                guard let caseDecl = enumMember.decl.as(EnumCaseDeclSyntax.self) else { continue }
                for element in caseDecl.elements {
                    names.insert(element.name.text)
                }
            }
            return names
        }
        return nil
    }
}

private struct ImmutableEditorPropertyWarning: DiagnosticMessage {
    let name: String

    var message: String {
        "Immutable property '\(name)' cannot be edited; make it var or mark it @NotEditable"
    }

    var diagnosticID: MessageID {
        MessageID(domain: "SBJLayout.CodableEditor", id: "immutable-property")
    }

    var severity: DiagnosticSeverity { .warning }
}

private enum CodableEditorMacroError: Error, CustomStringConvertible {
    case onlyStructsOrEnums

    var description: String {
        switch self {
        case .onlyStructsOrEnums:
            return "@CodableEditor can be applied only to structs or enums"
        }
    }
}
