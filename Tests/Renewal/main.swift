import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
let reset = Date(timeIntervalSince1970: 2_000_000)
let next = reset.addingTimeInterval(30 * 86400)
check(RenewalDetector.event(previousReset: reset, currentReset: next, observedAt: reset.addingTimeInterval(60)) != nil, "A confirmed new monthly window alerts")
check(RenewalDetector.event(previousReset: reset, currentReset: reset, observedAt: reset.addingTimeInterval(60)) == nil, "A pending reset never counts as renewed")
check(RenewalDetector.event(previousReset: reset, currentReset: next, observedAt: reset.addingTimeInterval(-60)) == nil, "Do not announce a renewal before its reset")
check(RenewalDetector.event(previousReset: nil, currentReset: next, observedAt: reset) == nil, "The first reading is not a renewal")
let first = RenewalDetector.event(previousReset: reset, currentReset: next, observedAt: reset.addingTimeInterval(60))!
let repeated = RenewalDetector.event(previousReset: reset, currentReset: next.addingTimeInterval(60), observedAt: reset.addingTimeInterval(120))!
check(first.id == repeated.id, "Repeated renewed readings share one notification identifier")
print("PASS: Cursor monthly renewals, pending resets and deduplication")
