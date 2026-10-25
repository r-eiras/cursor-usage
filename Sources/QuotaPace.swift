import Foundation

struct QuotaPace {
    let expectedFraction: Double
    let projectedFraction: Double
    var exceedsQuota: Bool { projectedFraction > 1.000001 }
    var label: String { exceedsQuota ? L("Tende a passar da cota", "On track to exceed the quota") : L("Dentro da cota neste ritmo", "Within the quota at this pace") }
    func markerPosition(remaining: Bool) -> Double { remaining ? 1 - expectedFraction : expectedFraction }

    static func estimate(usedFraction: Double, start: Date, end: Date, observedAt: Date, now: Date = Date()) -> QuotaPace? {
        let duration = end.timeIntervalSince(start), elapsed = observedAt.timeIntervalSince(start)
        guard usedFraction.isFinite, usedFraction >= 0, duration > 0, elapsed >= 60,
              observedAt <= now, observedAt < end, now < end else { return nil }
        let expected = elapsed / duration
        return QuotaPace(expectedFraction: min(1, max(0, expected)), projectedFraction: usedFraction / expected)
    }
}

struct HoverDismissalState {
    private var outsideSince: Date?
    mutating func reset() { outsideSince = nil }
    mutating func shouldDismiss(pointerInside: Bool, now: Date = Date()) -> Bool {
        if pointerInside { outsideSince = nil; return false }
        guard let outsideSince else { self.outsideSince = now; return false }
        return now.timeIntervalSince(outsideSince) >= 0.35
    }
}
