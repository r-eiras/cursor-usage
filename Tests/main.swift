import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let text = "Usage\nYour  monthly  usage\n$250.00 / $1,000.00\nResets  Nov 1, 2026\nTotal usage $25.00"
let snapshot = try UsageParser.parse(text, at: Date(timeIntervalSince1970: 1792688400))
check(snapshot.spentCents == 25000, "Read the personal monthly amount, not the filtered table total")
check(snapshot.limitCents == 100000, "Read the provider allocation")
check(snapshot.remainingCents == 75000, "Compute remaining allocation")
check(abs(snapshot.usedFraction - 0.25) < 0.00001, "Compute fraction")
let grouped = try UsageParser.parse("Your monthly usage $1,234.56 / $2,000.00 Resets Dec 1, 2026")
check(grouped.spentCents == 123456, "Handle thousands separators")
let currencyLocale = try UsageParser.parse("Your monthly usage US$250.00 / US$1,000.00 Resets 1 Nov 2026")
check(currencyLocale.spentCents == 25000 && currencyLocale.resetDate == snapshot.resetDate,
      "Parse the currency prefix and day-first renewal date in WebKit")
for invalid in ["Sign in", "Total usage $250.00 / $1,000.00 Resets Nov 1, 2026", "Your monthly usage $3 / $0 Resets Nov 1, 2026", "Your monthly usage $3 / $5 Resets Unknown"] {
    do { _ = try UsageParser.parse(invalid); fatalError("Reject missing or invalid quota") }
    catch is UsageParser.ParseError { }
}
let over = try UsageParser.parse("Your monthly usage $1,500 / $1,000.00 Resets Nov 1, 2026")
check(over.remainingCents == 0, "Do not report negative available quota")
check(UsageSnapshot.forecast(history: [snapshot]) == nil, "A single reading cannot establish burn rate")
let later = UsageSnapshot(spentCents: 35000, limitCents: 100000, resetDate: snapshot.resetDate, observedAt: snapshot.observedAt.addingTimeInterval(86400))
let forecast = UsageSnapshot.forecast(history: [snapshot, later])!
check(abs(forecast.dailyCents - 10000) < 0.01, "Forecast from observed changes, not invented cycle start")
let changedPlan = UsageSnapshot(spentCents: 35000, limitCents: 200000, resetDate: snapshot.resetDate, observedAt: later.observedAt)
check(UsageSnapshot.forecast(history: [snapshot, changedPlan]) == nil, "Never mix different allocations")
let shortInterval = UsageSnapshot(spentCents: 25100, limitCents: 100000, resetDate: snapshot.resetDate, observedAt: snapshot.observedAt.addingTimeInterval(60))
check(UsageSnapshot.forecast(history: [snapshot, shortInterval]) == nil, "Wait for a meaningful observation interval")
check(DashboardLocation.destination(for: URL(string: "https://cursor.com/dashboard")) == .dashboard,
      "After sign-in, navigate from Overview to Usage instead of waiting forever")
check(DashboardLocation.destination(for: URL(string: "https://www.cursor.com/dashboard/usage/")) == .usage,
      "Accept the official www host and trailing slash")
check(DashboardLocation.destination(for: URL(string: "https://authenticator.cursor.sh/")) == .signIn,
      "Do not interrupt the sign-in flow")
check(DashboardLocation.destination(for: URL(string: "https://cursor.com.attacker.example/dashboard")) == .signIn,
      "Never treat another host as the dashboard")
print("All quota and post-login navigation scenarios passed")
