import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
calendar.firstWeekday = 2
check(PeriodSelection().preset == .month, "New installations default to the current calendar month")
let restoredPeriod = try JSONDecoder().decode(PeriodSelection.self, from: Data(#"{"preset":"last7"}"#.utf8))
check(restoredPeriod.preset == .last7, "Existing saved periods remain unchanged")
let now = instant("2026-10-22T18:00:00Z")
let coverage = DateInterval(start: instant("2026-10-01T00:00:00Z"), end: instant("2026-10-23T00:00:00Z"))
let csv = """
Date,User,PR Author,Repo,Kind,Model,Input (w/ Cache Write),Input (w/o Cache Write),Cache Read,Output Tokens,Total Tokens,Cost
2026-10-22T16:00:00.000Z,self@example.test,,,Included,model-a,10,20,30,40,100,0.004
2026-10-22T02:00:00.000Z,self@example.test,,,Included,model-b,0,10,0,10,20,2.00
2026-10-19T15:00:00.000Z,self@example.test,,"repo,quoted",Included,model-b,0,10,0,10,20,3.00
2026-10-16T15:00:00.000Z,self@example.test,,,Included,model-a,0,10,0,10,20,1.00
2026-10-22T16:10:00.000Z,self@example.test,,,Included,model-a,,,,,,Free
"""
let data = try UsageCSV.parse(csv, coverage: coverage, fetchedAt: now)
check(data.events.count == 5, "Import every event, including free events with unreported tokens")
check(data.events[0].costMicros == 4000, "Preserve sub-cent costs before aggregation")
let quota = try UsageParser.parse("Your monthly usage US$250.00 / US$1,000.00 Resets 1 Nov 2026", at: now)
let today = AnalyticsEngine.report(dataset: data, selection: PeriodSelection(preset: .today), quota: quota, now: now, calendar: calendar)!
check(today.costMicros == 4000, "Use local midnight, not UTC midnight")
check(today.tokens == 100 && today.missingTokenEvents == 1, "Never invent zero tokens for unreported events")
let week = AnalyticsEngine.report(dataset: data, selection: PeriodSelection(preset: .week), quota: quota, now: now, calendar: calendar)!
check(week.costMicros == 5_004_000, "Calendar week starts on Monday and includes zero-use days")
let seven = AnalyticsEngine.report(dataset: data, selection: PeriodSelection(preset: .last7), quota: quota, now: now, calendar: calendar)!
check(seven.costMicros == 6_004_000 && seven.daily.count == 7, "Last seven calendar days includes today")
check(seven.models.first?.model == "model-b", "Rank models by cost, independently of token volume")
check(seven.models.first?.tokens == 40, "Sum exact model tokens")
check(seven.projection?.remainingDays == 10, "Interpret renewal as a local calendar date")
check(abs(seven.projection!.safeDailyMicros - 75_000_000) < 0.01, "Divide remaining quota across remaining calendar days")
let month = PeriodSelection(preset: .month)
let monthReport = AnalyticsEngine.report(dataset: data, selection: month, quota: quota, now: now, calendar: calendar)!
check(monthReport.interval.start == instant("2026-10-01T03:00:00Z") && monthReport.costMicros == 6_004_000, "Current month starts at local midnight on the first day of this month")
let legacyCustom = try JSONDecoder().decode(PeriodSelection.self, from: Data(#"{"preset":"custom","customStart":0,"customEnd":1}"#.utf8))
check(legacyCustom.preset == .month, "Removed custom selections migrate to the current month")
let shortData = UsageDataset(events: data.events, coverageStart: instant("2026-10-20T00:00:00Z"), coverageEnd: coverage.end, fetchedAt: now, accountDigest: data.accountDigest)
check(AnalyticsEngine.report(dataset: shortData, selection: PeriodSelection(preset: .last7), quota: quota, now: now, calendar: calendar) == nil, "Missing coverage is unavailable, not zero")
do {
    _ = try UsageCSV.parse(csv.replacingOccurrences(of: "2026-10-19T15:00:00.000Z,self@", with: "2026-10-19T15:00:00.000Z,other@"), coverage: coverage, fetchedAt: now)
    fatalError("Reject mixed-account exports")
} catch UsageCSV.ImportError.multipleAccounts { }
let encoded = String(data: try JSONEncoder().encode(data), encoding: .utf8)!
check(!encoded.contains("example.test") && !encoded.contains("repo,quoted"), "Persist model metrics without email or repository data")
print("PASS: CSV precision, local periods, coverage, model ranking, projection and account isolation")

let unknownModel = try UsageCSV.parse(csv.replacingOccurrences(of: "Included,model-a", with: "Included,"), coverage: coverage, fetchedAt: now, unknownModelName: "synthetic-unknown")
check(unknownModel.events.first?.model == "synthetic-unknown", "Background imports use one captured fallback label instead of reading mutable UI language")
