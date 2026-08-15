import Foundation

/// A key-path-based validation location. Property components are real Swift
/// key paths; collection positions are represented as indices rather than
/// stringly-typed path fragments.
public struct SBJValidationKeyPath: @unchecked Sendable, CustomStringConvertible {
    fileprivate enum Component {
        case property(AnyKeyPath)
        case index(Int)
    }

    fileprivate var components: [Component]

    public init<Root, Value>(_ keyPath: KeyPath<Root, Value>) {
        self.components = [.property(keyPath)]
    }

    fileprivate init(components: [Component]) {
        self.components = components
    }

    public func appending<Root, Value>(_ keyPath: KeyPath<Root, Value>) -> Self {
        .init(components: components + [.property(keyPath)])
    }

    public func appending(index: Int) -> Self {
        .init(components: components + [.index(index)])
    }

    public func contains(property keyPath: AnyKeyPath) -> Bool {
        components.contains { component in
            if case .property(let candidate) = component { return candidate == keyPath }
            return false
        }
    }

    public var description: String {
        components.map { component in
            switch component {
            case .property(let keyPath): return String(describing: keyPath)
            case .index(let index): return "[\(index)]"
            }
        }.joined(separator: ".")
    }
}

/// Standard validation failure used by generated and custom invariants.
public struct SBJValidationError: LocalizedError, @unchecked Sendable {
    public let keyPath: SBJValidationKeyPath
    public let message: String

    public init(_ message: String, at keyPath: SBJValidationKeyPath) {
        self.message = message
        self.keyPath = keyPath
    }

    public init<Root, Value>(_ message: String, at keyPath: KeyPath<Root, Value>) {
        self.init(message, at: SBJValidationKeyPath(keyPath))
    }

    public var errorDescription: String? { message }
}

/// App-level convenience helpers for handwritten domain invariants. Validation
/// ownership, paths, and the standard error type live in SBJLayout.
public func require(
    _ condition: @autoclosure () -> Bool,
    _ keyPath: SBJValidationKeyPath,
    _ requirement: String
) throws {
    try SBJInvariantCheck.require(condition(), at: keyPath, requirement)
}

public func requireMeaningful(_ value: String, _ keyPath: SBJValidationKeyPath) throws {
    try require(
        value.trimmingCharacters(in: .whitespacesAndNewlines).hasContent,
        keyPath,
        "must contain non-whitespace text"
    )
}

public func requireUnique<T: Hashable>(
    _ values: [T],
    _ keyPath: SBJValidationKeyPath,
    _ requirement: String
) throws {
    try require(Set(values).count == values.count, keyPath, requirement)
}

/// A value that can report whether it contains meaningful content and validate
/// its own domain invariants.
public protocol HasContentCheckable {
    var hasContent: Bool { get }
    func invariant(at keyPath: SBJValidationKeyPath) throws
}

public extension HasContentCheckable {
    func invariant(at keyPath: SBJValidationKeyPath) throws {}

    func invariant<Root>(at keyPath: KeyPath<Root, Self>) throws {
        try invariant(at: SBJValidationKeyPath(keyPath))
    }
}

extension String: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }
}

extension Optional: HasContentCheckable {
    public var hasContent: Bool {
        switch self {
        case .none: return false
        case .some(let wrapped):
            return (wrapped as? any HasContentCheckable)?.hasContent ?? true
        }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        guard case .some(let wrapped) = self,
              let checkable = wrapped as? any HasContentCheckable else { return }
        try checkable.invariant(at: keyPath)
    }
}

extension Array: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        return contains { ($0 as? any HasContentCheckable)?.hasContent ?? true }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for (index, element) in enumerated() {
            if let checkable = element as? any HasContentCheckable {
                try checkable.invariant(at: keyPath.appending(index: index))
            }
        }
    }
}

extension Set: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        return contains { ($0 as? any HasContentCheckable)?.hasContent ?? true }
    }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for element in self {
            if let checkable = element as? any HasContentCheckable {
                try checkable.invariant(at: keyPath)
            }
        }
    }
}

extension Dictionary: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }

    public func invariant(at keyPath: SBJValidationKeyPath) throws {
        for (_, value) in self {
            if let checkable = value as? any HasContentCheckable {
                try checkable.invariant(at: keyPath)
            }
        }
    }
}

public extension Sequence {
    var hasContent: Bool {
        var iterator = makeIterator()
        guard let first = iterator.next() else { return false }
        if let checkable = first as? any HasContentCheckable {
            if checkable.hasContent { return true }
            while let element = iterator.next() {
                if (element as? any HasContentCheckable)?.hasContent ?? true { return true }
            }
            return false
        }
        return true
    }
}

public enum SBJContentCheck {
    public static func hasContent<T>(_ value: T) -> Bool {
        (value as? any HasContentCheckable)?.hasContent ?? false
    }
}

/// Runtime bridge used by macro-generated invariants.
public enum SBJInvariantCheck {
    public static func validate<T>(_ value: T, at keyPath: SBJValidationKeyPath) throws {
        if let checkable = value as? any HasContentCheckable {
            try checkable.invariant(at: keyPath)
        }
    }

    public static func validationError<T>(_ value: T, at keyPath: SBJValidationKeyPath) -> SBJValidationError? {
        do {
            try validate(value, at: keyPath)
            return nil
        } catch let error as SBJValidationError {
            return error
        } catch {
            return SBJValidationError(error.localizedDescription, at: keyPath)
        }
    }

    public static func require(
        _ condition: @autoclosure () -> Bool,
        at keyPath: SBJValidationKeyPath,
        _ message: String
    ) throws {
        guard condition() else { throw SBJValidationError(message, at: keyPath) }
    }

    public static func requireRange(_ value: Int, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        try require(range.contains(value), at: keyPath, "must be in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Int?, _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange(_ values: [Int], _ range: ClosedRange<Int>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireRange(value, range, at: keyPath.appending(index: index))
        }
    }

    public static func requireMinimum(_ value: Int, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        try require(value >= minimum, at: keyPath, "must be at least \(minimum)")
    }

    public static func requireMinimum(_ value: Int?, _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireMinimum(value, minimum, at: keyPath) }
    }

    public static func requireMinimum(_ values: [Int], _ minimum: Int, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() {
            try requireMinimum(value, minimum, at: keyPath.appending(index: index))
        }
    }

    public static func requireRange(_ value: Double, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        try require(value.isFinite && range.contains(value), at: keyPath, "must be finite and in \(range.lowerBound)...\(range.upperBound)")
    }

    public static func requireRange(_ value: Double?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requireRange(_ values: [Double], _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        for (index, value) in values.enumerated() { try requireRange(value, range, at: keyPath.appending(index: index)) }
    }

    public static func requireRange(_ value: Float, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        try requireRange(Double(value), range, at: keyPath)
    }

    public static func requireRange(_ value: Float?, _ range: ClosedRange<Double>, at keyPath: SBJValidationKeyPath) throws {
        if let value { try requireRange(value, range, at: keyPath) }
    }

    public static func requirePresent<T>(_ value: T?, required: Bool, at keyPath: SBJValidationKeyPath) throws {
        if required { try require(value != nil, at: keyPath, "must be present") }
    }

    public static func requireText(_ value: String, minLength: Int?, maxLength: Int?, at keyPath: SBJValidationKeyPath) throws {
        if let minLength { try require(value.count >= minLength, at: keyPath, "must contain at least \(minLength) characters") }
        if let maxLength { try require(value.count <= maxLength, at: keyPath, "must contain at most \(maxLength) characters") }
    }

    public static func requireCount<C: Collection>(_ value: C, minCount: Int?, maxCount: Int?, at keyPath: SBJValidationKeyPath) throws {
        if let minCount { try require(value.count >= minCount, at: keyPath, "must contain at least \(minCount) elements") }
        if let maxCount { try require(value.count <= maxCount, at: keyPath, "must contain at most \(maxCount) elements") }
    }
}
