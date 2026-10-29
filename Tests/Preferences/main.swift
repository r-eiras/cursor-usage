import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
// Assertions below use the Portuguese texts; the language is fixed so the host Mac does not matter.
AppLanguage.current = .portuguese
func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
// Most checks below predate the weekend option and use calendar days; the weekday checks come at the end.
func everyDay() -> AppPreferences { var value = AppPreferences(); value.excludeWeekends = false; return value }
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
var preferences = everyDay()
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

var remaining = everyDay(); remaining.cursorUsageBasis = .remaining
let remainingBar = MenuBarPresentation.make(preferences: remaining, quota: quota, dataset: data, now: now, calendar: calendar)
check(remainingBar.title.contains("75%"), "Remaining usage complements the Cursor cycle")
check(abs((remainingBar.usedFraction ?? 0) - 0.25) < 0.0001 && remainingBar.iconUsage(.cycle) == remainingBar.usedFraction, "The icon color follows the share used even when the menu shows what remains")
check(remainingBar.iconUsage(.off) == nil && AppPreferences().iconColorBasis == .cycle, "Icon color starts on the cycle and can be turned off")
let colored = MenuBarPresentation(title: "", tooltip: "", fraction: nil, usedFraction: 0.8, usedTodayFraction: 0.4)
check(colored.iconUsage(.cycle) == 0.8 && colored.iconUsage(.day) == 0.4, "The color basis picks the cycle or today's share")
check(remainingBar.parts.map(\.text).joined() == remainingBar.title && remainingBar.parts.last?.usage == remainingBar.usedFraction, "The title's pieces carry the share used of their own period")
var todayOnly = everyDay(); todayOnly.menuBarDensity = .compactToday
let todayBar = MenuBarPresentation.make(preferences: todayOnly, quota: quota, dataset: data, now: now, calendar: calendar)
check(todayBar.parts.count == 1 && todayBar.parts[0].usage == todayBar.usedTodayFraction && !todayBar.title.contains("25%"), "Compact today shows only today's reading")
check(!AppPreferences().colorNumbers && MenuBarDensity.compactToday.showsText && !MenuBarDensity.iconsOnly.showsText, "Number colors start off; compact today is a text layout")
let personal = UsageSnapshot(spentCents: 3700, limitCents: 10_000, resetDate: date("2026-10-26T00:00:00Z"), observedAt: now, kind: .includedPercent, plan: "Free")
var personalPreferences = everyDay(); personalPreferences.menuMode = .both; personalPreferences.menuBarDensity = .detailed; personalPreferences.personalBudgetEnabled = true; personalPreferences.personalBudgetMicros = 5_000_000
let personalBar = MenuBarPresentation.make(preferences: personalPreferences, quota: personal, dataset: data, now: now, calendar: calendar)
check(personalBar.title == "37% Cota" && !personalBar.title.contains("US$") && !personalBar.title.contains("Hoje"), "A personal plan shows only its share, even when dollars and today are chosen")
check(personalBar.usedTodayFraction == nil && personalBar.iconUsage(.day) == personalBar.usedFraction && personalBar.tooltip.contains("Plano pessoal"), "Without daily figures the icon follows the included usage, and the plan is named")
personalPreferences.cursorUsageBasis = .remaining
check(MenuBarPresentation.make(preferences: personalPreferences, quota: personal, dataset: data, now: now, calendar: calendar).title.hasPrefix("63%"), "Remaining shows what is left of the included usage")
let personalBudget = BudgetEngine.assess(quota: personal, dataset: data, preferences: personalPreferences, now: now, calendar: calendar)!
check(personalBudget.isIncludedPercent && personalBudget.dailyLimitMicros == nil && personalBudget.targetMicros == 100_000_000 && abs(personalBudget.fraction - 0.37) < 0.0001, "A personal assessment ignores the dollar goal and has no daily allowance")
check(personalBudget.cycle.duration == 7 * 86400, "A reset a few days away is read as a weekly pool")
var personalAlert = everyDay(); personalAlert.notifyCycle = true; personalAlert.alertPercent = 30
let personalNotice = BudgetAlerts.candidates(assessment: personalBudget, preferences: personalAlert, delivered: [])
check(personalNotice.count == 1 && personalNotice[0].body.contains("37%") && !personalNotice[0].body.contains("US$"), "The cycle alert of a personal plan speaks in percent")
check(RenewalDetector.event(previousReset: date("2026-10-21T00:00:00Z"), currentReset: date("2026-10-28T00:00:00Z"), observedAt: date("2026-10-21T12:00:00Z"), minimumDaysAhead: 3) != nil
      && RenewalDetector.event(previousReset: date("2026-10-21T00:00:00Z"), currentReset: date("2026-10-28T00:00:00Z"), observedAt: date("2026-10-21T12:00:00Z")) == nil, "A weekly renewal counts only with the shorter minimum")
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
        var value = everyDay(); value.menuBarDensity = density
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
var thresholdPreferences = everyDay(); thresholdPreferences.notifyDaily = true; thresholdPreferences.dailyAlertPercent = 50
let thresholdBudget = BudgetEngine.assess(quota: quota, dataset: data, preferences: thresholdPreferences, now: now, calendar: calendar)!
check(BudgetAlerts.candidates(assessment: thresholdBudget, preferences: thresholdPreferences, delivered: []).isEmpty, "Daily alert stays quiet below the chosen fraction")
thresholdPreferences.personalBudgetEnabled = true; thresholdPreferences.personalBudgetMicros = 260_000_000
let smallerBudget = BudgetEngine.assess(quota: quota, dataset: data, preferences: thresholdPreferences, now: now, calendar: calendar)!
check(BudgetAlerts.candidates(assessment: smallerBudget, preferences: thresholdPreferences, delivered: []).contains { $0.kind == .daily }, "Daily threshold is applied to the calculated allowance")
print("PASS: configurable daily thresholds and persisted preferences")

var oldFiveMinutes = everyDay(); oldFiveMinutes.syncInterval = .fiveMinutes
let oldFiveRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(oldFiveMinutes))
check(oldFiveRestored.syncInterval == .standard && oldFiveRestored.syncInterval.seconds == 300, "Old five-minute choices keep their schedule after removing the duplicate option")

check(AppPreferences().menuOpenBehavior == .hoverAndClick, "New and existing users keep hover plus click by default")
var clickOnly = everyDay(); clickOnly.menuOpenBehavior = .clickOnly
let restoredClickOnly = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(clickOnly))
check(restoredClickOnly.menuOpenBehavior == .clickOnly, "Click-only opening survives an application restart")
var oldInteraction = try JSONSerialization.jsonObject(with: JSONEncoder().encode(clickOnly)) as! [String: Any]
oldInteraction.removeValue(forKey: "storedMenuOpenBehavior")
let oldInteractionRestored = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: oldInteraction))
check(oldInteractionRestored.menuOpenBehavior == .hoverAndClick, "Older preference files keep working without the new field")
print("PASS: menu opening preference, persistence and migration")


AppLanguage.current = .portuguese
var detailedPreference = everyDay()
let todayAndCycle = MenuBarPresentation.make(preferences: detailedPreference, quota: quota, dataset: data, now: now, calendar: calendar)
check(todayAndCycle.title == "3% Hoje · 25% Ciclo", "Detailed display compares observed daily use with the calculated allowance and cycle use with the cycle limit")
detailedPreference.menuBarDensity = .compact
check(MenuBarPresentation.make(preferences: detailedPreference, quota: quota, dataset: data, now: now, calendar: calendar).title == "25%", "Compact display keeps only the cycle percentage")

for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    for mode in MenuDisplayMode.allCases {
        for basis in [UsageDisplayBasis.used, .remaining] {
            var value = everyDay(); value.menuMode = mode; value.cursorUsageBasis = basis
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
var remainingDaily = everyDay(); remainingDaily.cursorUsageBasis = .remaining
let available = MenuBarPresentation.make(preferences: remainingDaily, quota: quota, dataset: data, now: now, calendar: calendar)
check(available.title == "97% Hoje · 75% Ciclo", "Remaining daily and cycle percentages each use their corresponding allowance")
let staleDaily = UsageDataset(events: data.events, coverageStart: data.coverageStart, coverageEnd: data.coverageEnd, fetchedAt: now.addingTimeInterval(-601), accountDigest: data.accountDigest)
let staleBar = MenuBarPresentation.make(preferences: everyDay(), quota: quota, dataset: staleDaily, now: now, calendar: calendar)
check(staleBar.title == "— Hoje · 25% Ciclo", "Stale daily history is unavailable rather than presented as current zero usage")
var personalDaily = everyDay(); personalDaily.personalBudgetEnabled = true; personalDaily.personalBudgetMicros = 500_000_000
check(MenuBarPresentation.make(preferences: personalDaily, quota: quota, dataset: data, now: now, calendar: calendar).title == "8% Hoje · 50% Ciclo", "Personal goals consistently change both daily and cycle reference limits")
print("PASS: detailed daily/cycle quota, optional labels, missing history, remaining amounts and personal goals")

var iconPreference = everyDay(); iconPreference.menuIconStyle = .cursor
let restoredIcon = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(iconPreference))
check(restoredIcon.menuIconStyle == .cursor, "The chosen menu icon survives restart")
print("PASS: independent app/Cursor icon preference")

check(AppPreferences().excludeWeekends && AppPreferences().weekendChoiceChangedAt == nil, "Weekends stay out of the daily quota by default, with no choice recorded")
var weekdayCalendar = calendar; weekdayCalendar.locale = Locale(identifier: "pt_BR")
var weekdayGoal = AppPreferences(); weekdayGoal.personalBudgetEnabled = true; weekdayGoal.personalBudgetMicros = 500_000_000; weekdayGoal.excludeWeekends = true
let restoredWeekdays = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(weekdayGoal))
check(restoredWeekdays.excludeWeekends, "The weekend choice survives restart")
let weekday = BudgetEngine.assess(quota: quota, dataset: data, preferences: weekdayGoal, now: now, calendar: weekdayCalendar)!
check(weekday.remainingDays == 7 && !weekday.isRestDay, "Thursday to a Sunday renewal leaves seven weekdays, today included")
check(abs(weekday.dailyLimitMicros! - 36_000_000) < 0.1, "The daily allowance spreads the balance before today over weekdays only")
check(abs(weekday.recommendedDailyMicros - 250_000_000.0 / 7) < 0.1, "Recommendations spread the remaining balance over weekdays only")
check(abs(weekday.plannedDailyMicros - 500_000_000.0 / 22) < 0.1, "The planned allowance divides the goal by the cycle's 22 weekdays")
check(abs(weekday.recentDailyMicros! - 67_000_000 / 4.625) < 0.1, "The recent pace counts only weekday time, so it compares with the weekday allowance")
check(abs(weekday.requiredSavingMicros - max(0, 67_000_000 / 4.625 - 250_000_000.0 / 7)) < 0.1, "Saving advice compares per-weekday pace and allowance")
let saturday = date("2026-10-24T18:00:00Z")
let saturdayQuota = try UsageParser.parse("Your monthly usage US$250.00 / US$1,000.00 Resets 1 Nov 2026", at: saturday)
let saturdayData = UsageDataset(events: data.events, coverageStart: data.coverageStart, coverageEnd: date("2026-10-25T00:00:00Z"), fetchedAt: saturday, accountDigest: data.accountDigest)
weekdayGoal.notifyDaily = true; weekdayGoal.dailyAlertPercent = 1
let rest = BudgetEngine.assess(quota: saturdayQuota, dataset: saturdayData, preferences: weekdayGoal, now: saturday, calendar: weekdayCalendar)!
check(rest.isRestDay && rest.dailyLimitMicros == nil && rest.remainingTodayMicros == nil, "A weekend day has no daily allowance")
check(rest.todaySpentMicros != nil && rest.remainingDays == 5, "Weekend spending is still known, and next week's five weekdays share the balance")
check(BudgetAlerts.candidates(assessment: rest, preferences: weekdayGoal, delivered: []).allSatisfy { $0.kind != .daily }, "No daily alert on a weekend")
weekdayGoal.iconColorBasis = .day
let restBar = MenuBarPresentation.make(preferences: weekdayGoal, quota: saturdayQuota, dataset: saturdayData, now: saturday, calendar: weekdayCalendar)
check(restBar.title.hasPrefix("— Hoje") && restBar.iconUsage(.day) == restBar.usedFraction, "A weekend shows no daily share, and a day-colored icon follows the cycle")
weekdayGoal.excludeWeekends = false
let calendarDays = BudgetEngine.assess(quota: saturdayQuota, dataset: saturdayData, preferences: weekdayGoal, now: saturday, calendar: weekdayCalendar)!
check(!calendarDays.isRestDay && calendarDays.dailyLimitMicros != nil && calendarDays.remainingDays == 8, "With the option off, weekends keep today's behavior")
print("PASS: optional weekday-only daily allowance, pace and weekend alerts")

var notices = AppPreferences(); notices.personalBudgetEnabled = true; notices.personalBudgetMicros = 500_000_000
let thursday = BudgetEngine.assess(quota: quota, dataset: data, preferences: notices, now: now, calendar: weekdayCalendar)!
let intro = WeekendNotices.candidates(assessment: thursday, preferences: notices, delivered: [], now: now, calendar: weekdayCalendar)
check(intro.map(\.id) == ["weekend-notice:excluded"] && intro[0].kind == .weekend, "The default says once that weekends are left out, with no alert turned on")
check(WeekendNotices.candidates(assessment: thursday, preferences: notices, delivered: ["weekend-notice:excluded"], now: now, calendar: weekdayCalendar).isEmpty, "That notice is said only once")
func spend(_ at: String) -> UsageEvent { UsageEvent(date: date(at), model: "model", kind: "Included", costMicros: 1_000_000, inputTokens: nil, cacheWriteTokens: nil, cacheReadTokens: nil, outputTokens: nil, totalTokens: 1) }
let busySaturday = UsageDataset(events: data.events + [spend("2026-10-24T15:00:00Z")], coverageStart: data.coverageStart, coverageEnd: date("2026-10-25T00:00:00Z"), fetchedAt: saturday, accountDigest: data.accountDigest)
let saturdayNotice = BudgetEngine.assess(quota: saturdayQuota, dataset: busySaturday, preferences: notices, now: saturday, calendar: weekdayCalendar)!
let used = WeekendNotices.candidates(assessment: saturdayNotice, preferences: notices, delivered: ["weekend-notice:excluded"], now: saturday, calendar: weekdayCalendar)
check(used.count == 1 && used[0].id.hasPrefix("weekend-notice:used:") && used[0].body.contains("desmarque"), "Weekend usage while weekends are left out says so, and how to count them")
let sunday = date("2026-10-25T18:00:00Z")
let sundayData = UsageDataset(events: busySaturday.events + [spend("2026-10-25T15:00:00Z")], coverageStart: data.coverageStart, coverageEnd: date("2026-10-26T00:00:00Z"), fetchedAt: sunday, accountDigest: data.accountDigest)
let sundayNotice = BudgetEngine.assess(quota: saturdayQuota, dataset: sundayData, preferences: notices, now: sunday, calendar: weekdayCalendar)!
check(WeekendNotices.candidates(assessment: sundayNotice, preferences: notices, delivered: ["weekend-notice:excluded", used[0].id], now: sunday, calendar: weekdayCalendar).isEmpty, "Saturday and Sunday are one weekend: one usage notice")
let idleSaturday = UsageDataset(events: [], coverageStart: data.coverageStart, coverageEnd: date("2026-10-25T00:00:00Z"), fetchedAt: saturday, accountDigest: data.accountDigest)
let idle = BudgetEngine.assess(quota: saturdayQuota, dataset: idleSaturday, preferences: notices, now: saturday, calendar: weekdayCalendar)!
check(WeekendNotices.candidates(assessment: idle, preferences: notices, delivered: ["weekend-notice:excluded"], now: saturday, calendar: weekdayCalendar).isEmpty, "A weekend without usage stays quiet")
notices.excludeWeekends = false
check(notices.weekendChoiceChangedAt != nil, "Changing the weekend choice records when")
let changed = date("2026-10-22T12:00:00Z"); notices.weekendChoiceChangedAt = changed
let counting = BudgetEngine.assess(quota: quota, dataset: data, preferences: notices, now: now, calendar: weekdayCalendar)!
check(WeekendNotices.candidates(assessment: counting, preferences: notices, delivered: ["weekend-notice:excluded"], now: changed.addingTimeInterval(23 * 3600), calendar: weekdayCalendar).isEmpty, "No reminder within a day of counting weekends again")
let reminder = WeekendNotices.candidates(assessment: counting, preferences: notices, delivered: ["weekend-notice:excluded"], now: changed.addingTimeInterval(25 * 3600), calendar: weekdayCalendar)
check(reminder.count == 1 && reminder[0].id == "weekend-notice:counted:\(Int(changed.timeIntervalSince1970))", "A day after counting weekends again, one reminder")
check(WeekendNotices.candidates(assessment: counting, preferences: notices, delivered: ["weekend-notice:excluded", reminder[0].id], now: changed.addingTimeInterval(9 * 86400), calendar: weekdayCalendar).isEmpty, "The reminder is said once per change")
check(WeekendNotices.candidates(assessment: personalBudget, preferences: AppPreferences(), delivered: [], now: now, calendar: weekdayCalendar).isEmpty, "A personal plan has no daily quota, so no weekend notices")
print("PASS: weekend notices once, once per weekend with usage, and a reminder a day after counting weekends again")
