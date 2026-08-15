import Testing
@testable import SBJLayout

struct StringUncamelCasedTests {
    @Test func uncamelCasesIdentifiers() {
        #expect("hitPoints".uncamelCased == "Hit Points")
        #expect("armorClass".uncamelCased == "Armor Class")
        #expect("URLValue".uncamelCased == "URL Value")
        #expect("myURLValue".uncamelCased == "My URL Value")
    }

    @Test func uncamelCasesSeparators() {
        #expect("spell_save_dc".uncamelCased == "Spell save dc")
        #expect("attack-bonus-rule".uncamelCased == "Attack bonus rule")
    }
}
