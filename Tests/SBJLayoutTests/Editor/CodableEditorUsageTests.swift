import Testing
@testable import SBJLayout

@CodableEditor
private struct TestNestedValue: Codable {
    var note: String = ""
}

@CodableEditor
private struct TestEditableValue: Codable {
    var name: String = ""
    var level: Int = 1
    var nested = TestNestedValue()
    var notes: [String] = []
    var nickname: String?
    @NotEditable var transientState: String = ""
    let immutableIdentifier: Int = 7

    enum CodingKeys: String, CodingKey {
        case name
        case level
        case nested
        case notes
        case nickname
    }
}

struct CodableEditorUsageTests {
    @Test func generatesFieldsFromCodedMutableProperties() {
        #expect(TestEditableValue.sbjEditorFields.map(\.name) == [
            "Name", "Level", "Nested", "Notes", "Nickname"
        ])
    }
}

@CodableEditor
private enum TestAssociatedEnum: Codable {
    case automatic
    case adjusted(amount: Int, enabled: Bool)
    case fixed(Int)
}

extension CodableEditorUsageTests {
    @MainActor
    @Test func generatesAssociatedEnumCasesAndFields() {
        let cases = TestAssociatedEnum.sbjEditorEnumCases
        #expect(cases.map(\.name) == ["Automatic", "Adjusted", "Fixed"])
        #expect(cases[0].associatedValues.isEmpty)
        #expect(cases[1].associatedValues.map(\.name) == ["Amount", "Enabled"])
        #expect(cases[2].associatedValues.map(\.name) == ["Value"])

        let created = TestAssociatedEnum.sbjCreateEditorValue()
        if case .automatic = created {
            // expected
        } else {
            Issue.record("Expected the first enum case to be the generated default")
        }
    }
}

@CodableEditor
private struct TestContentLeaf: Codable {
    var text: String = ""
}

@CodableEditor
private struct TestGeneratedContent: Codable {
    var scalar: Int = 1
    var text: String = ""
    var optionalText: String?
    var nested = TestContentLeaf()
    var nestedItems: [TestContentLeaf] = []
}

extension CodableEditorUsageTests {
    @Test func generatedHasContentDefaultsUnknownMembersToContent() {
        #expect(TestGeneratedContent().hasContent)
        #expect(TestGeneratedContent(scalar: 99).hasContent)
        #expect(TestGeneratedContent(text: "x").hasContent)
        #expect(!TestGeneratedContent(optionalText: "").hasContent)
        #expect(TestGeneratedContent(optionalText: "x").hasContent)
        #expect(TestGeneratedContent(nested: TestContentLeaf(text: "x")).hasContent)
        #expect(!TestGeneratedContent(nestedItems: [TestContentLeaf()]).hasContent)
        #expect(TestGeneratedContent(nestedItems: [TestContentLeaf(text: "x")]).hasContent)
    }
}

@CodableEditor
private struct TestValidatedValue: Codable {
    @EditorInteger(range: 1...20)
    var level: Int = 1

    @EditorText(minLength: 2, maxLength: 5)
    var code: String = "ok"

    @EditorArray(minCount: 1, maxCount: 2)
    var names: [String] = ["one"]

    @EditorOptional(required: true)
    var nickname: String? = "x"

    @EditorNumber(range: 0.0...1.0)
    var ratio: Double = 0.5
}

extension CodableEditorUsageTests {
    @Test func generatedInvariantUsesLocalEditorConstraints() throws {
        try TestValidatedValue().invariant(at: \TestValidatedValue.self)

        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(level: 21).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(code: "x").invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(names: []).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(nickname: nil).invariant(at: \TestValidatedValue.self)
        }
        #expect(throws: SBJValidationError.self) {
            try TestValidatedValue(ratio: 2).invariant(at: \TestValidatedValue.self)
        }
    }
}
