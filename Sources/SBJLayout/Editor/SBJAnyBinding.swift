import SwiftUI

/// A small type-erased binding used internally to cross protocol existential
/// boundaries while preserving two-way mutation.
public struct SBJAnyBinding {
    private let getter: @MainActor () -> Any
    private let setter: @MainActor (Any) -> Void

    @MainActor
    public init<Value>(_ binding: Binding<Value>) {
        getter = { binding.wrappedValue }
        setter = { binding.wrappedValue = $0 as! Value }
    }

    @MainActor
    public func get() -> Any { getter() }

    @MainActor
    public func set(_ value: Any) { setter(value) }
}
