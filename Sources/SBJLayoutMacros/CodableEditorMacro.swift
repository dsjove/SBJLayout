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
        var contentMembers: [String] = []
        var invariantStatements: [String] = []
        let hasExplicitHasContent = structDecl.memberBlock.members.contains { member in
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { return false }
            return variable.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "hasContent"
            }
        }
        let hasExplicitInvariant = structDecl.memberBlock.members.contains { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self) else { return false }
            return function.name.text == "invariant"
        }

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard !variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class) }) else {
                continue
            }
            for binding in variable.bindings {
                guard let identifier = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
                let name = identifier.identifier.text

                guard binding.accessorBlock == nil else { continue }
                if let codedNames, !codedNames.contains(name) { continue }

                if hasAttribute(named: "NotEditable", on: variable) { continue }

                if variable.bindingSpecifier.tokenKind == .keyword(.let) {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(identifier.identifier),
                            message: ImmutableEditorPropertyWarning(name: name)
                        )
                    )
                    continue
                }

                // Every actual editor field participates. SBJContentCheck only
                // counts values conforming to HasContentCheckable, so ordinary
                // scalar values naturally contribute false.
                contentMembers.append(name)
                invariantStatements.append("try SBJInvariantCheck.validate(\(name), at: keyPath.appending(\\Self.\(name)))")

                let textConstraints = editorTextConstraints(on: variable)
                if textConstraints.minLength != nil || textConstraints.maxLength != nil {
                    let minLength = textConstraints.minLength ?? "nil"
                    let maxLength = textConstraints.maxLength ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireText(\(name), minLength: \(minLength), maxLength: \(maxLength), at: keyPath.appending(\\Self.\(name)))")
                }
                let integerConstraints = editorIntegerConstraints(on: variable)
                if let integerRange = integerConstraints.range {
                    invariantStatements.append("try SBJInvariantCheck.requireRange(\(name), \(integerRange), at: keyPath.appending(\\Self.\(name)))")
                }
                if let integerMinimum = integerConstraints.min {
                    invariantStatements.append("try SBJInvariantCheck.requireMinimum(\(name), \(integerMinimum), at: keyPath.appending(\\Self.\(name)))")
                }
                let integerRange = integerConstraints.range ?? integerConstraints.min.map { "\($0)...Int.max" }
                if let numberRange = editorNumberRange(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requireRange(\(name), \(numberRange), at: keyPath.appending(\\Self.\(name)))")
                }
                if let required = editorOptionalRequired(on: variable) {
                    invariantStatements.append("try SBJInvariantCheck.requirePresent(\(name), required: \(required), at: keyPath.appending(\\Self.\(name)))")
                }
                let arrayOptions = editorArrayOptions(on: variable)
                if arrayOptions.minCount != nil || arrayOptions.maxCount != nil {
                    let minCount = arrayOptions.minCount ?? "nil"
                    let maxCount = arrayOptions.maxCount ?? "nil"
                    invariantStatements.append("try SBJInvariantCheck.requireCount(\(name), minCount: \(minCount), maxCount: \(maxCount), at: keyPath.appending(\\Self.\(name)))")
                }

                let textStyle = editorTextStyle(on: variable)
                let textStyleArgument = textStyle.map { ", textStyle: \($0)" } ?? ""
                let integerRangeArgument = integerRange.map { ", integerRange: \($0)" } ?? ""
                let arrayOrderingArgument = arrayOptions.ordering.map { ", arrayOrdering: \($0)" } ?? ""
                let arrayTitleArgument = arrayOptions.title.map { ", arrayItemTitleKey: \"\($0)\"" } ?? ""
                entries.append(
                    "SBJEditorField<Self>(name: \"\(name)\".uncamelCased, \\.\(name)\(textStyleArgument)\(integerRangeArgument)\(arrayOrderingArgument)\(arrayTitleArgument))"
                )
            }
        }

        let body = entries.joined(separator: ",\n            ")
        var result: [DeclSyntax] = [
            DeclSyntax(stringLiteral: """
            @MainActor
            \(access)static var sbjEditorFields: [SBJEditorField<Self>] {
                [
                    \(body)
                ]
            }
            """)
        ]

        let contentExpression = contentMembers.isEmpty
            ? "true"
            : contentMembers.map { "SBJContentCheck.hasContent(\($0))" }.joined(separator: " ||\n        ")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)var _hasContent: Bool {
                \(contentExpression)
            }
            """)
        )

        if !hasExplicitHasContent {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)var hasContent: Bool {
                    _hasContent
                }
                """)
            )
        }

        let invariantBody = invariantStatements.isEmpty ? "" : invariantStatements.joined(separator: "\n        ")
        result.append(
            DeclSyntax(stringLiteral: """
            \(access)func _invariant(at keyPath: SBJValidationKeyPath) throws {
                \(invariantBody)
            }
            """)
        )
        if !hasExplicitInvariant {
            result.append(
                DeclSyntax(stringLiteral: """
                \(access)func invariant(at keyPath: SBJValidationKeyPath) throws {
                    try _invariant(at: keyPath)
                }
                """)
            )
        }

        return result
    }

    // MARK: - Associated-value enums

    private struct EnumParameter {
        let type: String
        let fieldNameExpression: String
        let constructorLabel: String?
        let variableName: String
    }

    private struct EnumCaseInfo {
        let caseName: String
        let displayNameExpression: String
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

                    let fieldNameExpression: String
                    if let semanticName {
                        fieldNameExpression = "\"\(semanticName)\".uncamelCased"
                    } else if count == 1 {
                        fieldNameExpression = "\"Value\""
                    } else {
                        fieldNameExpression = "\"Value \(offset + 1)\""
                    }

                    return EnumParameter(
                        type: parameter.type.trimmedDescription,
                        fieldNameExpression: fieldNameExpression,
                        constructorLabel: constructorLabel,
                        variableName: "_sbjValue\(offset)"
                    )
                }
                result.append(
                    EnumCaseInfo(
                        caseName: caseName,
                        displayNameExpression: "\"\(caseName)\".uncamelCased",
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
            name: \(info.displayNameExpression),
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
            name: \(parameter.fieldNameExpression),
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


    private static func editorTextConstraints(on variable: VariableDeclSyntax) -> (minLength: String?, maxLength: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorText" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return (nil, nil) }
            var minLength: String?
            var maxLength: String?
            for argument in arguments {
                switch argument.label?.text {
                case "minLength": minLength = argument.expression.trimmedDescription
                case "maxLength": maxLength = argument.expression.trimmedDescription
                default: break
                }
            }
            return (minLength, maxLength)
        }
        return (nil, nil)
    }

    private static func editorNumberRange(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorNumber" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return nil }
            for argument in arguments where argument.label?.text == "range" {
                return argument.expression.trimmedDescription
            }
        }
        return nil
    }

    private static func editorOptionalRequired(on variable: VariableDeclSyntax) -> String? {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorOptional" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else { return "true" }
            for argument in arguments where argument.label?.text == "required" {
                return argument.expression.trimmedDescription
            }
            return "true"
        }
        return nil
    }

    private static func editorIntegerConstraints(on variable: VariableDeclSyntax) -> (range: String?, min: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorInteger" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return (nil, nil)
            }
            for argument in arguments where argument.label?.text == "range" {
                return (argument.expression.trimmedDescription, nil)
            }
            for argument in arguments where argument.label?.text == "min" {
                return (nil, argument.expression.trimmedDescription)
            }
        }
        return (nil, nil)
    }

    private static func editorArrayOptions(on variable: VariableDeclSyntax) -> (ordering: String?, title: String?, minCount: String?, maxCount: String?) {
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            guard attribute.attributeName.trimmedDescription == "EditorArray" else { continue }
            guard let rawArguments = attribute.arguments,
                  case .argumentList(let arguments) = rawArguments else {
                return ("true", nil, nil, nil)
            }

            var ordering: String? = "true"
            var title: String?
            var minCount: String?
            var maxCount: String?
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
                    } else {
                        title = keyPathPropertyName(from: expression)
                    }
                case "minCount": minCount = argument.expression.trimmedDescription
                case "maxCount": maxCount = argument.expression.trimmedDescription
                default:
                    continue
                }
            }
            return (ordering, title, minCount, maxCount)
        }
        return (nil, nil, nil, nil)
    }

    private static func keyPathPropertyName(from expression: String) -> String? {
        guard expression.hasPrefix("\\") else { return nil }
        let body = String(expression.dropFirst())
        guard let component = body.split(separator: ".").last, !component.isEmpty else {
            return nil
        }
        return String(component)
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
