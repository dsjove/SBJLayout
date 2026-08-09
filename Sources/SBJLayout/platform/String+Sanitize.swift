import Foundation

public extension String {
	func sanitizedFilename(
		removeSpaces: Bool = false,
		replacement: String = "-"
	) -> String {
		let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return "" }

		let originalName = trimmed // we assume no path
		guard !originalName.isEmpty else { return "" }

		let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
			.union(.newlines)
			.union(.illegalCharacters)
			.union(.controlCharacters)

		var result = ""
		var lastWasReplacement = false

		for scalar in originalName.unicodeScalars {
			if invalid.contains(scalar) {
				if !replacement.isEmpty && !lastWasReplacement {
					result += replacement
					lastWasReplacement = true
				}
			} else {
				result.unicodeScalars.append(scalar)
				lastWasReplacement = false
			}
		}

		while result.hasPrefix(replacement), !replacement.isEmpty {
			result.removeFirst(replacement.count)
		}

		while result.hasSuffix(replacement), !replacement.isEmpty {
			result.removeLast(replacement.count)
		}

		if removeSpaces {
			result = result.replacingOccurrences(of: " ", with: "")
		}

		result = result.trimmingCharacters(in: .whitespacesAndNewlines)

		let reservedWindowsNames: Set<String> = [
			"CON", "PRN", "AUX", "NUL",
			"COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
			"LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
		]

		let baseName = URL(fileURLWithPath: result).deletingPathExtension().lastPathComponent
		if reservedWindowsNames.contains(baseName.uppercased()) {
			result = "_" + result
		}

		return result
	}

	var isValidCVariableName: Bool {
		let regex = "^[a-zA-Z_][a-zA-Z0-9_]*$"
		return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
	}

	var sanitizeCVariableName: String {
		let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimmed.isValidCVariableName {
			return trimmed
		}

		var sanitizedName = ""
		if let first = self.first, String(first).range(of: "^[a-zA-Z_]$", options: .regularExpression) != nil {
			sanitizedName.append(first)
		}
		else {
			sanitizedName.append("_") // Default to '_' if invalid first character
		}
		let validSubsequentRegex = "[a-zA-Z0-9_]"
		for char in self.dropFirst() {
			if String(char).range(of: validSubsequentRegex, options: .regularExpression) != nil {
				sanitizedName.append(char)
			}
			else {
				sanitizedName.append("_")
			}
		}
		return sanitizedName
	}
}
