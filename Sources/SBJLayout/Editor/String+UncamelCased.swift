import Foundation

public extension String {
    /// Converts a Swift-style identifier into a human-readable label while
    /// preserving acronym boundaries.
    ///
    /// Examples: `hitPoints` -> `Hit Points`, `URLValue` -> `URL Value`.
    nonisolated var uncamelCased: String {
        guard !isEmpty else { return self }
        let characters = Array(self)
        var result = ""
        result.reserveCapacity(characters.count + characters.count / 4)

        for index in characters.indices {
            let character = characters[index]

            if character == "_" || character == "-" {
                if result.last != " " { result.append(" ") }
                continue
            }

            if index > characters.startIndex {
                let previous = characters[index - 1]
                let next = index + 1 < characters.endIndex ? characters[index + 1] : nil
                let previousWasSeparator = previous == "_" || previous == "-"
                let startsNewWord = character.isUppercase && !previousWasSeparator && (
                    previous.isLowercase || previous.isNumber ||
                    (previous.isUppercase && next?.isLowercase == true)
                )
                if startsNewWord, result.last != " " { result.append(" ") }
            }

            result.append(character)
        }

        return result.prefix(1).uppercased() + result.dropFirst()
    }
}
