import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
// Assertions below use the Portuguese texts; the language is fixed so the host Mac does not matter.
AppLanguage.current = .portuguese
func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
let now = date("2026-10-22T18:00:00Z")
let quota = try UsageParser.parse("Your monthly usage US$250.00 / US$1,000.00 Resets 1 Nov 2026", at: now)
let csv = """
Date,User,Kind,Model,Total Tokens,Cost
2026-10-22T16:00:00Z,self@example.test,Included,model,100,2.00
2026-10-21T16:00:00Z,self@example.test,Included,model,100,50
2026-10-20T16:00:00Z,self@example.test,Included,model,100,10
2026-10-19T16:00:00Z,self@example.test,Included,model,100,5
"""
let data = try UsageCSV.parse(csv, coverage: DateInterval(start: date("2026-10-01T00:00:00Z"), end: date("2026-10-23T00:00:00Z")), fetchedAt: now)
var preferences = AppPreferences()
check(!preferences.notifyCycle && !preferences.notifyDaily && !preferences.personalBudgetEnabled, "New installations do not enable alerts or choose a personal target")
let three = PeriodSelection(preset: .last3).interval(now: now, calendar: calendar)!
check(three.start == date("2026-10-20T03:00:00Z"), "Three days means today plus two local calendar days")
let defaultBar = MenuBarPresentation.make(preferences: preferences, quota: quota, dataset: data, now: now, calendar: calendar)
check(defaultBar.title.contains("25%"), "Keep the existing cycle percentage by default")
preferences.menuMode = .both
let bothBar = MenuBarPresentation.make(preferences: preferences, quota: quota, dataset: data, now: now, calendar: calendar)
check(bothBar.title.contains("25%") && bothBar.title.contains("250,00"), "Both mode shows the subscription quota percentage and amount")
preferences.menuMode = .amount
let moneyBar = MenuBarPresentation.make(preferences: preferences, quota: quota, dataset: data, now: now, calendar: calendar)
check(moneyBar.title.contains("250,00") && !moneyBar.title.contains("%"), "Amount-only mode shows cycle spending")
let noHistory = MenuBarPresentation.make(preferences: preferences, quota: quota, dataset: nil, now: now, calendar: calendar)
check(noHistory.title.contains("250,00") && noHistory.title.contains("—"), "Keep the known cycle amount and mark missing daily history unavailable")
preferences.personalBudgetEnabled = true; preferences.personalBudgetMicros = 500_000_000
let budget = BudgetEngine.assess(quota: quota, dataset: data, preferences: preferences, now: now, calendar: calendar)!
check(budget.remainingDays == 10 && budget.remainingMicros == 250_000_000, "Personal target is separate from provider quota")
check(abs(budget.dailyLimitMicros! - 25_200_000) < 0.1, "Daily allowance uses the balance before today's spending, so it does not shrink while spending today")
check(abs(budget.remainingTodayMicros! - 23_200_000) < 0.1, "Show what is still available today")
check(abs(budget.recommendedDailyMicros - 25_000_000) < 0.1, "Future recommendations use the remaining balance, not the daily allowance before spending")
check(BudgetAlerts.candidates(assessment: budget, preferences: preferences, delivered: []).isEmpty, "Disabled alerts stay silent even above a threshold")
preferences.notifyCycle = true; preferences.alertPercent = 40
let alerts = BudgetAlerts.candidates(assessment: budget, preferences: preferences, delivered: [])
check(alerts.count == 1 && alerts[0].kind == .cycle, "Emit a target threshold alert only after opt-in")
check(BudgetAlerts.candidates(assessment: budget, preferences: preferences, delivered: Set(alerts.map(\.id))).isEmpty, "Do not repeat the alert after polling or restarting")
preferences.notifyDaily = true; preferences.personalBudgetMicros = 260_000_000
let exceeded = BudgetEngine.assess(quota: quota, dataset: data, preferences: preferences, now: now, calendar: calendar)!
check(exceeded.overDailyLimit && exceeded.requiredSavingMicros > 0, "Overspending produces a daily warning and a concrete saving amount")
check(BudgetAlerts.candidates(assessment: exceeded, preferences: preferences, delivered: []).contains { $0.kind == .daily }, "Daily notification is opt-in and independent of the target notification")
let staleBudget = BudgetEngine.assess(quota: quota, dataset: data, preferences: preferences, now: now.addingTimeInterval(601), calendar: calendar)!
check(!BudgetAlerts.candidates(assessment: staleBudget, preferences: preferences, delivered: []).contains { $0.kind == .daily }, "Stale daily data must not trigger a daily notification")

let noDailyData = BudgetEngine.assess(quota: quota, dataset: nil, preferences: preferences, now: now, calendar: calendar)!
check(!BudgetAlerts.candidates(assessment: noDailyData, preferences: preferences, delivered: []).contains { $0.kind == .daily }, "Never alert about an unknown daily cost")
let dailyAlerts = BudgetAlerts.candidates(assessment: exceeded, preferences: preferences, delivered: [])
check(BudgetAlerts.candidates(assessment: exceeded, preferences: preferences, delivered: Set(dailyAlerts.map(\.id))).isEmpty, "Deduplicate both notification types")
preferences.personalBudgetMicros = 268_000_000
let exactlyAtDailyLimit = BudgetEngine.assess(quota: quota, dataset: data, preferences: preferences, now: now, calendar: calendar)!
check(!exactlyAtDailyLimit.overDailyLimit, "Daily alert requires exceeding, not merely reaching, the daily cap")
let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(preferences))
check(restored.menuMode == .amount && restored.notifyDaily, "Persist choices across app restarts")
print("PASS: menu formats, three days, personal budget, daily allowance, opt-in and deduplicated alerts")

check(AppPreferences().syncInterval == .standard, "Existing default remains five minutes")
check(SyncInterval.allCases.map(\.seconds) == [300, 60, 600], "Offer one, default five and ten minutes without duplicate choices")
var syncPreferences = preferences
syncPreferences.syncInterval = .tenMinutes
let syncRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(syncPreferences))
check(syncRestored.syncInterval == .tenMinutes && syncRestored.menuMode == preferences.menuMode, "Persist sync interval alongside current choices")
var legacyObject = try JSONSerialization.jsonObject(with: JSONEncoder().encode(syncPreferences)) as! [String: Any]
legacyObject.removeValue(forKey: "storedSyncInterval")
let legacyRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: legacyObject))
check(legacyRestored.syncInterval == .standard && legacyRestored.notifyDaily == preferences.notifyDaily, "Upgrade old preferences without resetting user choices")
print("PASS: synchronization options, persistence and backwards compatibility")

var remaining = AppPreferences(); remaining.cursorUsageBasis = .remaining
let remainingBar = MenuBarPresentation.make(preferences: remaining, quota: quota, dataset: data, now: now, calendar: calendar)
check(remainingBar.title.contains("75%"), "Remaining usage complements the Cursor cycle")
remaining.menuMode = .amount
check(MenuBarPresentation.make(preferences: remaining, quota: quota, dataset: data, now: now, calendar: calendar).title.contains("750,00"), "Remaining money follows the same cycle")
var compact = remaining; compact.menuBarDensity = .iconsOnly
check(MenuBarPresentation.make(preferences: compact, quota: quota, dataset: data, now: now, calendar: calendar).title.isEmpty, "Icons-only keeps the Cursor icon without text")
AppLanguage.current = .english
check(MenuBarPresentation.money(250_000_000) == "$250.00", "English currency uses a decimal point")
check(UsagePeriod.today.title == "Today", "English periods are localized")
AppLanguage.current = .portuguese
check(MenuBarPresentation.money(250_000_000).contains("250,00"), "Brazilian Portuguese currency uses a comma")
check(UsagePeriod.today.title == "Hoje", "Brazilian Portuguese periods are localized")
check(AppPreferences().personalBudgetMicros == 0, "Do not assume a personal spending goal")
print("PASS: Cursor remaining values, display density, languages and neutral defaults")

for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    for density in [MenuBarDensity.detailed, .compact, .iconsOnly] {
        var value = AppPreferences(); value.menuBarDensity = density
        let bar = MenuBarPresentation.make(preferences: value, quota: quota, dataset: data, now: now, calendar: calendar)
        check(density != .compact || !bar.title.contains(L("Ciclo", "Cycle")), "Compact mode omits daily and cycle labels")
        check(density == .iconsOnly ? bar.title.isEmpty : bar.title.contains("25%"), "Text modes show the cycle and logo-only mode keeps text empty")
    }
}
AppLanguage.current = .portuguese
var obsoleteFields = try JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as! [String: Any]
obsoleteFields["menuPeriod"] = "today"; obsoleteFields["showPeriodLabel"] = true; obsoleteFields["percentageReference"] = "period"
let migrated = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: obsoleteFields))
let migratedBar = MenuBarPresentation.make(preferences: migrated, quota: quota, dataset: data, now: now, calendar: calendar)
let currentBar = MenuBarPresentation.make(preferences: preferences, quota: quota, dataset: data, now: now, calendar: calendar)
check(migratedBar.title == currentBar.title && migrated.notifyDaily, "Obsolete period fields are ignored without resetting the user's other preferences")
print("PASS: cycle-only menu bar, text densities and obsolete preference migration")
var thresholdPreferences = AppPreferences(); thresholdPreferences.notifyDaily = true; thresholdPreferences.dailyAlertPercent = 50
let thresholdBudget = BudgetEngine.assess(quota: quota, dataset: data, preferences: thresholdPreferences, now: now, calendar: calendar)!
check(BudgetAlerts.candidates(assessment: thresholdBudget, preferences: thresholdPreferences, delivered: []).isEmpty, "Daily alert stays quiet below the chosen fraction")
thresholdPreferences.personalBudgetEnabled = true; thresholdPreferences.personalBudgetMicros = 260_000_000
let smallerBudget = BudgetEngine.assess(quota: quota, dataset: data, preferences: thresholdPreferences, now: now, calendar: calendar)!
check(BudgetAlerts.candidates(assessment: smallerBudget, preferences: thresholdPreferences, delivered: []).contains { $0.kind == .daily }, "Daily threshold is applied to the calculated allowance")
print("PASS: configurable daily thresholds and persisted preferences")

var oldFiveMinutes = AppPreferences(); oldFiveMinutes.syncInterval = .fiveMinutes
let oldFiveRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(oldFiveMinutes))
check(oldFiveRestored.syncInterval == .standard && oldFiveRestored.syncInterval.seconds == 300, "Old five-minute choices keep their schedule after removing the duplicate option")

check(AppPreferences().menuOpenBehavior == .hoverAndClick, "New and existing users keep hover plus click by default")
var clickOnly = AppPreferences(); clickOnly.menuOpenBehavior = .clickOnly
let restoredClickOnly = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(clickOnly))
check(restoredClickOnly.menuOpenBehavior == .clickOnly, "Click-only opening survives an application restart")
var oldInteraction = try JSONSerialization.jsonObject(with: JSONEncoder().encode(clickOnly)) as! [String: Any]
oldInteraction.removeValue(forKey: "storedMenuOpenBehavior")
let oldInteractionRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: oldInteraction))
check(oldInteractionRestored.menuOpenBehavior == .hoverAndClick, "Older preference files keep working without the new field")
print("PASS: menu opening preference, persistence and migration")


AppLanguage.current = .portuguese
var detailedPreference = AppPreferences()
let todayAndCycle = MenuBarPresentation.make(preferences: detailedPreference, quota: quota, dataset: data, now: now, calendar: calendar)
check(todayAndCycle.title == "3% Hoje · 25% Ciclo", "Detailed display compares observed daily use with the calculated allowance and cycle use with the cycle limit")
detailedPreference.menuBarDensity = .compact
check(MenuBarPresentation.make(preferences: detailedPreference, quota: quota, dataset: data, now: now, calendar: calendar).title == "25%", "Compact display keeps only the cycle percentage")

for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    for mode in MenuDisplayMode.allCases {
        for basis in [UsageDisplayBasis.used, .remaining] {
            var value = AppPreferences(); value.menuMode = mode; value.cursorUsageBasis = basis
            let detailed = MenuBarPresentation.make(preferences: value, quota: quota, dataset: data, now: now, calendar: calendar)
            value.menuBarDensity = .compact
            let compact = MenuBarPresentation.make(preferences: value, quota: quota, dataset: data, now: now, calendar: calendar)
            check(detailed.title != compact.title && detailed.fraction == compact.fraction, "Detailed adds the daily quota without changing the cycle calculation")
            value.menuBarDensity = .detailed; value.showDetailedLabels = false
            let unlabeled = MenuBarPresentation.make(preferences: value, quota: quota, dataset: data, now: now, calendar: calendar)
            check(!unlabeled.title.contains(L("Hoje", "Today")) && !unlabeled.title.contains(L("Ciclo", "Cycle")), "Hide only the labels, retaining both quota values")
            let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(value))
            check(!restored.showDetailedLabels, "Persist the detailed label preference")
        }
    }
}
AppLanguage.current = .portuguese
var remainingDaily = AppPreferences(); remainingDaily.cursorUsageBasis = .remaining
let available = MenuBarPresentation.make(preferences: remainingDaily, quota: quota, dataset: data, now: now, calendar: calendar)
check(available.title == "97% Hoje · 75% Ciclo", "Remaining daily and cycle percentages each use their corresponding allowance")
let staleDaily = UsageDataset(events: data.events, coverageStart: data.coverageStart, coverageEnd: data.coverageEnd, fetchedAt: now.addingTimeInterval(-601), accountDigest: data.accountDigest)
let staleBar = MenuBarPresentation.make(preferences: AppPreferences(), quota: quota, dataset: staleDaily, now: now, calendar: calendar)
check(staleBar.title == "— Hoje · 25% Ciclo", "Stale daily history is unavailable rather than presented as current zero usage")
var personalDaily = AppPreferences(); personalDaily.personalBudgetEnabled = true; personalDaily.personalBudgetMicros = 500_000_000
check(MenuBarPresentation.make(preferences: personalDaily, quota: quota, dataset: data, now: now, calendar: calendar).title == "8% Hoje · 50% Ciclo", "Personal goals consistently change both daily and cycle reference limits")
print("PASS: detailed daily/cycle quota, optional labels, missing history, remaining amounts and personal goals")

var iconPreference = AppPreferences(); iconPreference.menuIconStyle = .cursor
let restoredIcon = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(iconPreference))
check(restoredIcon.menuIconStyle == .cursor, "The chosen menu icon survives restart")
print("PASS: independent app/Cursor icon preference")
