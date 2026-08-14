import Testing
@testable import SBJLayout

struct SBJEditorLabelTests {
    @Test func humanizesCamelCase() {
        #expect(SBJEditorLabel.humanize("hitPoints") == "Hit Points")
        #expect(SBJEditorLabel.humanize("armorClass") == "Armor Class")
    }

    @Test func humanizesSeparators() {
        #expect(SBJEditorLabel.humanize("spell_save_dc") == "Spell Save Dc")
    }
}
