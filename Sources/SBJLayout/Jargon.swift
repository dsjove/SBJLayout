import Foundation

public struct JargonFormatter: Sendable {
	private let formatter: @Sendable (any Sendable) -> String?

	public init<Value: Sendable>(
		_ type: Value.Type = Value.self,
		_ formatter: @escaping @Sendable (Value) -> String
	) {
		self.formatter = { value in
			guard let value = value as? Value else { return nil }
			return formatter(value)
		}
	}

	public func format<Value: Sendable>(_ value: Value) -> String? {
		formatter(value)
	}
}

public struct Jargon: Sendable, Identifiable {
	public let id: String
	private let words: [String: String]
	private let formatters: [String: JargonFormatter]

	public init(
		_ id: String,
		overriding base: Jargon? = nil,
		words: [String: String] = [:],
		formatters: [String: JargonFormatter] = [:]
	) {
		self.id = id
		self.words = base?.words.merging(words) { _, override in override } ?? words
		self.formatters = base?.formatters.merging(formatters) { _, override in override } ?? formatters
	}

	public func word(_ key: String) -> String? {
		words[key]
	}

	public func text(_ key: String?) -> String? {
		guard let key else { return nil }
		return word(key) ?? key
	}

	public func formatter(_ key: String) -> JargonFormatter? {
		formatters[key]
	}

	public func format<Value: Sendable>(_ key: String?, value: Value) -> String? {
		guard let key else { return nil }
		return formatter(key)?.format(value)
	}

	public static let standard = Jargon("Standard")
}
