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
// Personal plans: the dashboard overview shows a share of the included usage, not dollars.
let overview = "Renan\nFree\nOverview\nYour included usage\n37% used\nResets 4 Nov 2026\nPremium"
let included = try UsageParser.parseIncluded(overview, plan: "Free", at: Date(timeIntervalSince1970: 1792688400))
check(included.isIncludedPercent && included.spentCents == 3700 && included.limitCents == 10_000 && included.plan == "Free", "A personal plan's share is read as hundredths of a percent of 10,000")
check(Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: included.resetDate).day == 4, "The personal reset date is read")
check((try? UsageParser.parseIncluded("Your included usage 12.5% used Resets Nov 4, 2026"))?.spentCents == 1250, "Decimal shares are kept")
check((try? UsageParser.parseIncluded("Your monthly usage $250.00 / $1,000.00 Resets Nov 1, 2026")) == nil && (try? UsageParser.parse(overview)) == nil, "Each parser only accepts its own kind of account")
let legacy = try JSONDecoder().decode(UsageSnapshot.self, from: Data(#"{"spentCents":100,"limitCents":200,"resetDate":0,"observedAt":0}"#.utf8))
check(legacy.kind == nil && !legacy.isIncludedPercent, "Readings saved before personal accounts stay dollar readings")
let spendingPaid = "Spending\nOn-Demand Usage\nUsed this cycle\n$12.40 / $50.00\nEdit limit"
check(UsageParser.parseOnDemand(spendingPaid).map { [$0.spentCents, $0.limitCents] } == [1240, 5000], "On-demand money is read with its limit")
check(UsageParser.parseOnDemand("On-Demand Usage US$ 3.00 of US$ 20.00")?.limitCents == 2000, "Either separator is understood")
check(UsageParser.parseOnDemand("Spending\nOn-Demand Usage\nEnable on-demand usage to go beyond your plan's included usage. Requires a paid plan.") == nil, "A free plan has no on-demand money")
check(UsageParser.parseOnDemand("Premium R$154.90 /mo. $20 / $40") == nil, "Amounts outside the on-demand section are ignored")
check(DashboardLocation.destination(for: URL(string: "https://cursor.com/api/auth/bootstrap-cursor-web-target?x=1")) == .authRedirect, "Cursor's auth bootstrap is a step on the way, not a sign-in")
check(DashboardLocation.destination(for: URL(string: "https://cursor.com.attacker.example/api/auth/bootstrap")) == .signIn, "Only Cursor's own auth steps pass")
print("All quota and post-login navigation scenarios passed")
