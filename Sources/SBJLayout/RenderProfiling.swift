import Foundation
import CoreGraphics
/*
#if DEBUG
internal enum RenderProfiling {
    enum Kind: String, Hashable {
        case minimumMeasure
        case measure
    }

    private struct PhaseKey: Hashable {
        let type: String
        let phase: String
    }

    private struct PhaseStats {
        var count = 0
        var total: TimeInterval = 0
        var max: TimeInterval = 0
    }

    private struct ElementBoundsKey: Hashable {
        let elementID: UInt64
        let width: CGFloat
        let height: CGFloat
    }

    private struct ElementTypeStats {
        var minimumCalls = 0
        var measureCalls = 0
        var minimumKeys: [ElementBoundsKey: Int] = [:]
        var measureKeys: [ElementBoundsKey: Int] = [:]
        var minimumElements: Set<UInt64> = []
        var measureElements: Set<UInt64> = []

        // A duplicate minimum probe can either immediately repeat the previous
        // bounds for this element, or revisit bounds after probing something else
        // (for example A -> B -> A). Distinguishing these tells us whether the
        // existing one-entry measurement state is simply too small for the access
        // pattern, versus callers issuing the same request back-to-back.
        var lastMinimumKeyByElement: [UInt64: ElementBoundsKey] = [:]
        var minimumConsecutiveDuplicates = 0
        var minimumRevisitedDuplicates = 0
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var phaseStats: [PhaseKey: PhaseStats] = [:]
    nonisolated(unsafe) private static var elementStats: [String: ElementTypeStats] = [:]
    nonisolated(unsafe) private static var startedAt: TimeInterval?
    nonisolated(unsafe) private static var nextElementID: UInt64 = 1

    @inline(__always)
    static func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    static func begin() {
        lock.lock()
        phaseStats.removeAll(keepingCapacity: true)
        elementStats.removeAll(keepingCapacity: true)
        startedAt = now()
        lock.unlock()
    }

    static func makeElementID() -> UInt64 {
        lock.lock()
        let value = nextElementID
        nextElementID &+= 1
        lock.unlock()
        return value
    }

    @inline(__always)
    static func recordPhase(type: Any.Type, phase: String, startedAt: TimeInterval) {
        let duration = now() - startedAt
        let key = PhaseKey(type: String(describing: type), phase: phase)
        lock.lock()
        var value = phaseStats[key] ?? PhaseStats()
        value.count += 1
        value.total += duration
        value.max = max(value.max, duration)
        phaseStats[key] = value
        lock.unlock()
    }

    static func recordElementCall(
        id: UInt64,
        type: Any.Type,
        kind: Kind,
        bounds: CGSize
    ) {
        let typeName = String(describing: type)
        let key = ElementBoundsKey(elementID: id, width: bounds.width, height: bounds.height)
        lock.lock()
        var value = elementStats[typeName] ?? ElementTypeStats()
        switch kind {
        case .minimumMeasure:
            value.minimumCalls += 1
            if value.minimumKeys[key] != nil {
                if value.lastMinimumKeyByElement[id] == key {
                    value.minimumConsecutiveDuplicates += 1
                } else {
                    value.minimumRevisitedDuplicates += 1
                }
            }
            value.minimumKeys[key, default: 0] += 1
            value.minimumElements.insert(id)
            value.lastMinimumKeyByElement[id] = key
        case .measure:
            value.measureCalls += 1
            value.measureKeys[key, default: 0] += 1
            value.measureElements.insert(id)
        }
        elementStats[typeName] = value
        lock.unlock()
    }

    static func reportAndReset(label: String) {
        let finished = now()
        lock.lock()
        let phaseSnapshot = phaseStats
        let elementSnapshot = elementStats
        let start = startedAt
        phaseStats.removeAll(keepingCapacity: true)
        elementStats.removeAll(keepingCapacity: true)
        startedAt = nil
        lock.unlock()

        let wall = start.map { finished - $0 } ?? 0
        print("[RENDERPROFILE] ---- \(label) wall=\(format(wall)) ----")

        let phaseRows = phaseSnapshot.map { (key: $0.key, stats: $0.value) }.sorted {
            if $0.stats.total == $1.stats.total { return $0.key.type < $1.key.type }
            return $0.stats.total > $1.stats.total
        }
        for row in phaseRows {
            let avg = row.stats.count == 0 ? 0 : row.stats.total / Double(row.stats.count)
            print("[RENDERPROFILE] phase \(row.key.phase) \(row.key.type) count=\(row.stats.count) total=\(format(row.stats.total)) avg=\(format(avg)) max=\(format(row.stats.max))")
        }

        let elementRows = elementSnapshot.sorted { lhs, rhs in
            let leftCalls = lhs.value.minimumCalls + lhs.value.measureCalls
            let rightCalls = rhs.value.minimumCalls + rhs.value.measureCalls
            if leftCalls == rightCalls { return lhs.key < rhs.key }
            return leftCalls > rightCalls
        }
        for (type, stats) in elementRows {
            let minUnique = stats.minimumKeys.count
            let measureUnique = stats.measureKeys.count
            let minDuplicates = stats.minimumCalls - minUnique
            let measureDuplicates = stats.measureCalls - measureUnique
            let sameElements = stats.minimumElements.intersection(stats.measureElements).count
            let sameElementBounds = Set(stats.minimumKeys.keys).intersection(Set(stats.measureKeys.keys)).count
            print("[RENDERPROFILE] calls \(type) min=\(stats.minimumCalls) minUnique=\(minUnique) minDuplicates=\(minDuplicates) minDuplicateConsecutive=\(stats.minimumConsecutiveDuplicates) minDuplicateRevisit=\(stats.minimumRevisitedDuplicates) measure=\(stats.measureCalls) measureUnique=\(measureUnique) measureDuplicates=\(measureDuplicates) sameElements=\(sameElements) sameElementBounds=\(sameElementBounds)")
        }
        print("[RENDERPROFILE] ---- end ----")
    }

    private static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.3fms", seconds * 1000)
    }
}
#else
internal enum RenderProfiling {
    enum Kind { case minimumMeasure, measure }
    @inline(__always) static func now() -> TimeInterval { 0 }
    static func begin() {}
    static func makeElementID() -> UInt64 { 0 }
    @inline(__always) static func recordPhase(type: Any.Type, phase: String, startedAt: TimeInterval) {}
    static func recordElementCall(id: UInt64, type: Any.Type, kind: Kind, bounds: CGSize) {}
    static func reportAndReset(label: String) {}
}
#endif
*/
