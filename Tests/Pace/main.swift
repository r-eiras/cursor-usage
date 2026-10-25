import Foundation
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
let start = Date(timeIntervalSince1970: 1000), end = start.addingTimeInterval(5 * 3600), observed = start.addingTimeInterval(2 * 3600)
let pace = QuotaPace.estimate(usedFraction: 0.6, start: start, end: end, observedAt: observed, now: observed)!
check(abs(pace.expectedFraction - 0.4) < 0.00001, "The pace marker follows elapsed quota-window time")
check(abs(pace.projectedFraction - 1.5) < 0.00001 && pace.exceedsQuota, "60 percent in two of five hours projects exhaustion before renewal")
check(abs(pace.markerPosition(remaining: true) - 0.6) < 0.00001, "Reverse the marker when showing remaining quota")
let safe = QuotaPace.estimate(usedFraction: 0.2, start: start, end: end, observedAt: observed, now: observed)!
check(!safe.exceedsQuota && abs(safe.projectedFraction - 0.5) < 0.00001, "A safe pace projects below the quota")
check(QuotaPace.estimate(usedFraction: 0.4, start: start, end: end, observedAt: start, now: start) == nil, "Do not divide by zero when a window starts")
check(QuotaPace.estimate(usedFraction: 0.4, start: start, end: end, observedAt: observed, now: end) == nil, "Do not project an expired window as current")
check(QuotaPace.estimate(usedFraction: .nan, start: start, end: end, observedAt: observed, now: observed) == nil, "Invalid data cannot produce a pace forecast")
var hover = HoverDismissalState()
check(!hover.shouldDismiss(pointerInside: false, now: start), "Allow crossing the gap from icon to popup")
check(!hover.shouldDismiss(pointerInside: true, now: start.addingTimeInterval(0.2)), "Entering the popup cancels the pending dismissal")
check(!hover.shouldDismiss(pointerInside: false, now: start.addingTimeInterval(1)), "A new exit gets its own grace period")
check(hover.shouldDismiss(pointerInside: false, now: start.addingTimeInterval(1.4)), "Close after leaving the icon and popup, including another display")
print("PASS: quota pace, remaining marker, forecast boundaries and hover gap tolerance")
