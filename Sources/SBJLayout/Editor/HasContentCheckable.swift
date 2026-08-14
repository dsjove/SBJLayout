/// A value that can report whether it contains meaningful user/model content.
///
/// `@CodableEditor` types automatically conform. Container conformances delegate
/// to contained values when those values are themselves `HasContentCheckable`;
/// otherwise ordinary presence/non-emptiness is treated as content.
public protocol HasContentCheckable {
    var hasContent: Bool { get }
}

extension String: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }
}

extension Optional: HasContentCheckable {
    public var hasContent: Bool {
        switch self {
        case .none:
            return false
        case .some(let wrapped):
            if let checkable = wrapped as? any HasContentCheckable {
                return checkable.hasContent
            }
            return true
        }
    }
}

extension Array: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        for element in self {
            if let checkable = element as? any HasContentCheckable {
                if checkable.hasContent { return true }
            } else {
                return true
            }
        }
        return false
    }
}

extension Set: HasContentCheckable {
    public var hasContent: Bool {
        guard !isEmpty else { return false }
        for element in self {
            if let checkable = element as? any HasContentCheckable {
                if checkable.hasContent { return true }
            } else {
                return true
            }
        }
        return false
    }
}

extension Dictionary: HasContentCheckable {
    public var hasContent: Bool { !isEmpty }
}

public extension Sequence {
    /// Generic sequence content semantics for sequence types that do not have a
    /// more-specific `HasContentCheckable` conformance.
    var hasContent: Bool {
        var iterator = makeIterator()
        guard let first = iterator.next() else { return false }

        if let checkable = first as? any HasContentCheckable {
            if checkable.hasContent { return true }
            while let element = iterator.next() {
                if let checkable = element as? any HasContentCheckable {
                    if checkable.hasContent { return true }
                } else {
                    return true
                }
            }
            return false
        }

        return true
    }
}

/// Runtime bridge used by macro-generated content checks. Values with no
/// meaningful content semantics (for example ordinary numeric or enum scalars)
/// simply contribute `false` to the enclosing generated OR expression.
public enum SBJContentCheck {
    public static func hasContent<T>(_ value: T) -> Bool {
        (value as? any HasContentCheckable)?.hasContent ?? false
    }
}
