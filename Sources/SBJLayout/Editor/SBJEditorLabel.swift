import Foundation

public enum SBJEditorLabel {
    /// Converts common Swift identifiers into UI labels.
    ///
    /// Examples: `hitPoints` -> `Hit Points`, `armor_class` -> `Armor Class`.
    public static func humanize(_ identifier: String) -> String {
        guard !identifier.isEmpty else { return identifier }

        var result = ""
        var previousWasLowerOrDigit = false

        for scalar in identifier.unicodeScalars {
            let character = Character(scalar)

            if character == "_" || character == "-" {
                if !result.hasSuffix(" ") { result.append(" ") }
                previousWasLowerOrDigit = false
                continue
            }

            let string = String(character)
            let isUpper = string == string.uppercased() && string != string.lowercased()
            let isLower = string == string.lowercased() && string != string.uppercased()
            let isDigit = character.isNumber

            if isUpper && previousWasLowerOrDigit && !result.hasSuffix(" ") {
                result.append(" ")
            }

            result.append(character)
            previousWasLowerOrDigit = isLower || isDigit
        }

        return result
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { word in
                guard let first = word.first else { return "" }
                return String(first).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
