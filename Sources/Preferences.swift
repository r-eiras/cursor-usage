import Foundation

enum MenuDisplayMode: String, Codable, CaseIterable {
    case percentage, amount, both
    var title: String { switch self { case .percentage: return L("Porcentagem", "Percentage"); case .amount: return L("Valor em US$", "Amount in US$"); case .both: return L("Porcentagem e valor", "Percentage and amount") } }
}
enum SyncInterval: String, Codable, CaseIterable {
    case standard, oneMinute, fiveMinutes, tenMinutes
    // Keep decoding the old explicit five-minute value without offering two identical choices.
    static let allCases: [SyncInterval] = [.standard, .oneMinute, .tenMinutes]
    var seconds: TimeInterval { switch self { case .oneMinute: return 60; case .tenMinutes: return 600; case .standard, .fiveMinutes: return 300 } }
    var title: String { switch self { case .standard: return L("Padrão (5 minutos)", "Default (5 minutes)"); case .oneMinute: return L("1 minuto", "1 minute"); case .fiveMinutes: return L("5 minutos", "5 minutes"); case .tenMinutes: return L("10 minutos", "10 minutes") } }
}
enum UsageDisplayBasis: String, Codable, CaseIterable {
    case used, remaining
    var title: String { self == .used ? L("Consumido", "Used") : L("Restante", "Remaining") }
}
enum MenuBarDensity: String, Codable, CaseIterable {
    case detailed, compact, compactToday, iconsOnly
    var title: String {
        switch self {
        case .detailed: return L("Detalhada (hoje e ciclo)", "Detailed (today and cycle)"); case .compact: return L("Compacta (ciclo)", "Compact (cycle)")
        case .compactToday: return L("Compacta (hoje)", "Compact (today)"); case .iconsOnly: return L("Somente logos", "Logos only")
        }
    }
    var showsText: Bool { self != .iconsOnly }
}
enum MenuIconStyle: String, Codable, CaseIterable {
    case app, cursor
    var title: String { self == .app ? "Cursor Usage" : "Cursor" }
}
// What the menu bar icon's color follows: nothing, the share of the cycle used, or the share of today's allowance used.
enum IconColorBasis: String, Codable, CaseIterable {
    case off, cycle, day
    var title: String { switch self { case .off: return L("Ícone sem cor", "Icon without color"); case .cycle: return L("Ícone pelo uso do ciclo", "Icon by cycle usage"); case .day: return L("Ícone pelo uso do dia", "Icon by today's usage") } }
}
// The rate alert's threshold: a share above the reference's usual 15 minutes, or a dollar amount above it.
enum RateThresholdUnit: String, Codable, CaseIterable {
    case percent, amount
    var title: String { self == .percent ? "%" : "US$" }
}
enum MenuOpenBehavior: String, Codable, CaseIterable {
    case hoverAndClick, clickOnly
    var title: String {
        self == .hoverAndClick ? L("Ao passar o mouse ou clicar", "On hover or click") : L("Somente ao clicar", "On click only")
    }
}
// A model the user chose to watch, with optional goals in micro-dollars. Cursor itself has no per-model limit.
struct MonitoredModel: Codable, Equatable {
    var model: String
    var dailyLimitMicros: Int64?
    var cycleLimitMicros: Int64?
}

struct AppPreferences: Codable {
    private var storedSyncInterval: SyncInterval?
    private var storedMenuIconStyle: MenuIconStyle?
    private var storedShowDetailedLabels: Bool?
    private var storedMenuOpenBehavior: MenuOpenBehavior?
    private var storedMenuBarDensity: MenuBarDensity?
    private var storedCursorUsageBasis: UsageDisplayBasis?
    private var storedDailyAlertPercent: Double?
    private var storedNotifyRenewal: Bool?
    private var storedLanguage: AppLanguage?
    private var storedNotifyNewModel: Bool?
    private var storedNotifyModelRate: Bool?
    private var storedModelRatePercent: Int?
    private var storedMonitoredModels: [MonitoredModel]?
    private var storedIconColorBasis: IconColorBasis?
    private var storedColorNumbers: Bool?
    private var storedModelRateUnit: RateThresholdUnit?
    private var storedModelRateAmountMicros: Int64?
    private var storedModelRateReference: String?
    var menuIconStyle: MenuIconStyle { get { storedMenuIconStyle ?? .app } set { storedMenuIconStyle = newValue } }
    var showDetailedLabels: Bool { get { storedShowDetailedLabels ?? true } set { storedShowDetailedLabels = newValue } }
    var menuOpenBehavior: MenuOpenBehavior { get { storedMenuOpenBehavior ?? .hoverAndClick } set { storedMenuOpenBehavior = newValue } }
    var syncInterval: SyncInterval { get { storedSyncInterval == .fiveMinutes ? .standard : storedSyncInterval ?? .standard } set { storedSyncInterval = newValue } }
    var menuBarDensity: MenuBarDensity { get { storedMenuBarDensity ?? .detailed } set { storedMenuBarDensity = newValue } }
    var cursorUsageBasis: UsageDisplayBasis { get { storedCursorUsageBasis ?? .used } set { storedCursorUsageBasis = newValue } }
    var dailyAlertPercent: Double { get { storedDailyAlertPercent ?? 100 } set { storedDailyAlertPercent = newValue.isFinite ? min(100, max(1, newValue)) : 100 } }
    var notifyRenewal: Bool { get { storedNotifyRenewal ?? false } set { storedNotifyRenewal = newValue } }
    var language: AppLanguage { get { storedLanguage ?? .system } set { storedLanguage = newValue } }
    // Model alerts need no setup, so they start on; like the update notice, the first one asks macOS for permission.
    var notifyNewModel: Bool { get { storedNotifyNewModel ?? true } set { storedNotifyNewModel = newValue } }
    var notifyModelRate: Bool { get { storedNotifyModelRate ?? true } set { storedNotifyModelRate = newValue } }
    var modelRatePercent: Int { get { storedModelRatePercent ?? 50 } set { storedModelRatePercent = min(10_000, max(1, newValue)) } }
    var monitoredModels: [MonitoredModel] { get { storedMonitoredModels ?? [] } set { storedMonitoredModels = newValue } }
    var iconColorBasis: IconColorBasis { get { storedIconColorBasis ?? .cycle } set { storedIconColorBasis = newValue } }
    // Today's and the cycle's numbers each take the color of their own usage.
    var colorNumbers: Bool { get { storedColorNumbers ?? false } set { storedColorNumbers = newValue } }
    var modelRateUnit: RateThresholdUnit { get { storedModelRateUnit ?? .percent } set { storedModelRateUnit = newValue } }
    var modelRateAmountMicros: Int64 { get { storedModelRateAmountMicros ?? 1_000_000 } set { storedModelRateAmountMicros = min(100_000_000_000, max(10_000, newValue)) } }
    // nil compares with the costliest model; a name compares with that model, even after it leaves the history.
    var modelRateReference: String? { get { storedModelRateReference } set { storedModelRateReference = newValue?.isEmpty == true ? nil : newValue } }
    var freshnessInterval: TimeInterval { max(600, syncInterval.seconds + 60) }
    var menuMode: MenuDisplayMode = .percentage
    var showIcon = true
    var personalBudgetEnabled = false
    var personalBudgetMicros: Int64 = 0
    var notifyCycle = false
    var alertPercent = 80
    var notifyDaily = false
    var alertSound = false
}

struct BudgetAssessment {
    let targetMicros: Int64
    let spentMicros: Int64
    let remainingMicros: Int64
    let cycle: DateInterval
    let remainingDays: Int
    let plannedDailyMicros: Double
    let recommendedDailyMicros: Double
    let dailyLimitMicros: Double?
    let todaySpentMicros: Int64?
    let remainingTodayMicros: Double?
    let recentDailyMicros: Double?
    let requiredSavingMicros: Double
    let projectedCycleMicros: Double?
    let cycleKey: String
    let dayKey: String
    let dailyDataFresh: Bool
    // A personal plan's reading: shares of its included usage, with no dollars and no daily figures.
    var isIncludedPercent = false
    var fraction: Double { Double(spentMicros) / Double(targetMicros) }
    var overDailyLimit: Bool { guard let todaySpentMicros, let dailyLimitMicros else { return false }; return Double(todaySpentMicros) > dailyLimitMicros }
}

enum BudgetEngine {
    static func assess(quota: UsageSnapshot, dataset: UsageDataset?, preferences: AppPreferences, now: Date, calendar: Calendar = .current) -> BudgetAssessment? {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let reset = calendar.date(from: utc.dateComponents([.year, .month, .day], from: quota.resetDate)) else { return nil }
        if quota.isIncludedPercent {
            // Only the share used is known: no personal goal in dollars, no daily allowance, no spending rate.
            let start = reset.timeIntervalSince(now) <= 8 * 86400 ? reset.addingTimeInterval(-7 * 86400) : (calendar.date(byAdding: .month, value: -1, to: reset) ?? reset)
            guard start <= now, reset > now else { return nil }
            let target = Int64(quota.limitCents) * 10_000, spent = Int64(quota.spentCents) * 10_000
            let days = max(1, calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: reset).day ?? 1)
            let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
            return BudgetAssessment(targetMicros: target, spentMicros: spent, remainingMicros: max(0, target - spent), cycle: DateInterval(start: start, end: reset), remainingDays: days,
                plannedDailyMicros: 0, recommendedDailyMicros: 0, dailyLimitMicros: nil, todaySpentMicros: nil, remainingTodayMicros: nil, recentDailyMicros: nil,
                requiredSavingMicros: 0, projectedCycleMicros: nil, cycleKey: String(Int(quota.resetDate.timeIntervalSince1970)), dayKey: formatter.string(from: now),
                dailyDataFresh: false, isIncludedPercent: true)
        }
        guard let start = calendar.date(byAdding: .month, value: -1, to: reset), start <= now, reset > now else { return nil }
        let target = preferences.personalBudgetEnabled ? preferences.personalBudgetMicros : Int64(quota.limitCents) * 10_000
        guard target > 0 else { return nil }
        let spent = Int64(quota.spentCents) * 10_000
        let today = calendar.startOfDay(for: now)
        let days = max(1, calendar.dateComponents([.day], from: today, to: reset).day ?? 1)
        let cycleDays = max(1, calendar.dateComponents([.day], from: start, to: reset).day ?? 1)
        let todayReport = dataset.flatMap { AnalyticsEngine.report(dataset: $0, selection: PeriodSelection(preset: .today), quota: nil, now: now, calendar: calendar) }
        let todaySpent = todayReport?.costMicros
        let dailyLimit = todaySpent.map { Double(max(0, target - max(0, spent - $0))) / Double(days) }
        let recentReport = dataset.flatMap { AnalyticsEngine.report(dataset: $0, selection: PeriodSelection(preset: .last7), quota: nil, now: now, calendar: calendar) }
        let rate = recentReport.map { Double($0.costMicros) / max(1.0 / 24, now.timeIntervalSince($0.interval.start) / 86400) }
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        return BudgetAssessment(targetMicros: target, spentMicros: spent, remainingMicros: max(0, target - spent), cycle: DateInterval(start: start, end: reset), remainingDays: days,
            plannedDailyMicros: Double(target) / Double(cycleDays), recommendedDailyMicros: Double(max(0, target - spent)) / Double(days), dailyLimitMicros: dailyLimit,
            todaySpentMicros: todaySpent, remainingTodayMicros: todaySpent.flatMap { value in dailyLimit.map { max(0, $0 - Double(value)) } },
            recentDailyMicros: rate, requiredSavingMicros: max(0, (rate ?? 0) - Double(max(0, target - spent)) / Double(days)),
            projectedCycleMicros: rate.map { Double(spent) + $0 * reset.timeIntervalSince(now) / 86400 },
            cycleKey: String(Int(quota.resetDate.timeIntervalSince1970)), dayKey: formatter.string(from: now),
            dailyDataFresh: dataset.map { now.timeIntervalSince($0.fetchedAt) <= preferences.freshnessInterval } ?? false)
    }
}

struct MenuBarPresentation {
    let title: String
    let tooltip: String
    let fraction: Double?
    // Share used, whatever the menu shows: a remaining amount must not turn the icon red while plenty is left.
    var usedFraction: Double? = nil, usedTodayFraction: Double? = nil
    // The title in pieces, each with the share used it may be colored by; separators and labels-only pieces carry none.
    struct Part: Equatable { let text: String; let usage: Double? }
    var parts: [Part] = []
    // The fraction the icon color follows, or nil when coloring is off or the day's figures are not fresh.
    // A personal plan has no daily figure, so a day basis follows its included usage instead.
    var isIncludedPercent = false
    func iconUsage(_ basis: IconColorBasis) -> Double? { basis == .cycle || (basis == .day && isIncludedPercent) ? usedFraction : basis == .day ? usedTodayFraction : nil }
    static func money(_ micros: Double) -> String {
        let formatter = NumberFormatter(); formatter.locale = AppLanguage.locale; formatter.numberStyle = .currency; formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: micros / 1_000_000)) ?? "—"
    }
    static func make(preferences: AppPreferences, quota: UsageSnapshot?, dataset: UsageDataset?, now: Date, calendar: Calendar = .current, assessment: BudgetAssessment? = nil) -> MenuBarPresentation {
        let budget = assessment ?? quota.flatMap { BudgetEngine.assess(quota: $0, dataset: dataset, preferences: preferences, now: now, calendar: calendar) }
        if let quota, quota.isIncludedPercent { return included(quota, preferences: preferences) }
        let cost = quota.map { Int64($0.spentCents) * 10_000 }
        let denominator = budget.map { Double($0.targetMicros) } ?? quota.map { Double($0.limitCents) * 10_000 }
        let displayedCost = cost.flatMap { cost -> Double? in
            if preferences.cursorUsageBasis == .used { return Double(cost) }
            return denominator.map { max(0, $0 - Double(cost)) }
        }
        let fraction = displayedCost.flatMap { cost in denominator.flatMap { $0 > 0 ? cost / $0 : nil } }
        func percentage(_ value: Double?) -> String {
            value.map { localizedDecimal(String(format: $0 * 100 < 1 && $0 > 0 ? "%.1f%%" : "%.0f%%", $0 * 100)) } ?? "—"
        }
        func content(cost: Double?, fraction: Double?) -> String {
            let percent = percentage(fraction), amount = cost.map(money) ?? "—"
            switch preferences.menuMode { case .percentage: return percent; case .amount: return amount; case .both: return "\(percent) · \(amount)" }
        }
        let percent = percentage(fraction), amount = displayedCost.map(money) ?? "—"
        let freshDaily = budget?.dailyDataFresh == true
        let dailyCost = freshDaily ? (preferences.cursorUsageBasis == .used ? budget?.todaySpentMicros.map(Double.init) : budget?.remainingTodayMicros) : nil
        let dailyFraction = dailyCost.flatMap { spent in budget?.dailyLimitMicros.flatMap { $0 > 0 ? spent / $0 : nil } }
        let cycleContent = content(cost: displayedCost, fraction: fraction)
        let dailyContent = content(cost: dailyCost, fraction: dailyFraction)
        let qualifier = preferences.cursorUsageBasis == .used ? L("consumidos", "used") : L("disponíveis", "available")
        let usedFraction = cost.flatMap { cost in denominator.flatMap { $0 > 0 ? Double(cost) / $0 : nil } }
        let usedTodayFraction = freshDaily ? budget?.todaySpentMicros.flatMap { spent in budget?.dailyLimitMicros.flatMap { $0 > 0 ? Double(spent) / $0 : nil } } : nil
        let parts: [Part]
        switch preferences.menuBarDensity {
        case .detailed:
            let today = preferences.showDetailedLabels ? dailyContent + L(" Hoje", " Today") : dailyContent
            let cycle = preferences.showDetailedLabels ? cycleContent + L(" Ciclo", " Cycle") : cycleContent
            parts = [Part(text: today, usage: usedTodayFraction), Part(text: " · ", usage: nil), Part(text: cycle, usage: usedFraction)]
        case .compact: parts = [Part(text: cycleContent, usage: usedFraction)]
        case .compactToday: parts = [Part(text: dailyContent, usage: usedTodayFraction)]
        case .iconsOnly: parts = []
        }
        let title = parts.map(\.text).joined()
        return MenuBarPresentation(title: title,
            tooltip: "\(L("Hoje", "Today")): \(dailyContent) \(qualifier)\n\(L("Cota diária calculada", "Calculated daily allowance")): \(freshDaily ? budget?.dailyLimitMicros.map(money) ?? "—" : "—")\n\(L("Ciclo da assinatura", "Subscription cycle")): \(amount) \(qualifier)\n\(percent) \(L("do limite do ciclo", "of the cycle limit")): \(denominator.map(money) ?? L("indisponível", "unavailable"))\n\(preferences.personalBudgetEnabled ? L("Referência: sua meta pessoal", "Reference: your personal goal") : L("Referência: cota oficial", "Reference: official quota"))", fraction: fraction,
            usedFraction: usedFraction, usedTodayFraction: usedTodayFraction, parts: parts)
    }
}

struct BudgetAlert {
    enum Kind { case cycle, daily, renewal, window, newModel, modelRate, modelLimit }
    let id: String
    let kind: Kind
    let title: String
    let body: String
}
extension MenuBarPresentation {
    // A personal plan shows only the share of its included usage: no dollars and no daily number, whatever the layout.
    static func included(_ quota: UsageSnapshot, preferences: AppPreferences) -> MenuBarPresentation {
        let used = Double(quota.spentCents) / Double(quota.limitCents)
        let shown = preferences.cursorUsageBasis == .used ? used : max(0, 1 - used)
        let percent = localizedDecimal(String(format: shown * 100 < 1 && shown > 0 ? "%.1f%%" : "%.0f%%", shown * 100))
        let label = preferences.menuBarDensity == .detailed && preferences.showDetailedLabels ? percent + L(" Cota", " Quota") : percent
        let parts = preferences.menuBarDensity == .iconsOnly ? [] : [Part(text: label, usage: used)]
        let formatter = DateFormatter(); formatter.locale = AppLanguage.locale; formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "d MMM"
        let plan = L("Plano pessoal", "Personal plan")
        return MenuBarPresentation(title: parts.map(\.text).joined(),
            tooltip: "\(plan)\n\(L("Cota incluída", "Included usage")): \(percent) \(preferences.cursorUsageBasis == .used ? L("usada", "used") : L("disponível", "left"))\n\(L("Renova em", "Renews on")) \(formatter.string(from: quota.resetDate))",
            fraction: shown, usedFraction: used, usedTodayFraction: nil, parts: parts, isIncludedPercent: true)
    }
}

enum BudgetAlerts {
    static func candidates(assessment: BudgetAssessment, preferences: AppPreferences, delivered: Set<String>) -> [BudgetAlert] {
        var result: [BudgetAlert] = []
        let limitKey = "\(assessment.cycleKey):\(assessment.targetMicros)"
        if preferences.notifyCycle && assessment.fraction * 100 >= Double(preferences.alertPercent) {
            let id = "cycle:\(limitKey):\(preferences.alertPercent)"
            if !delivered.contains(id) {
                result.append(BudgetAlert(id: id, kind: .cycle, title: QuotaMessages.alertTitle("Cursor"), body: assessment.isIncludedPercent
                    ? L("\(Int((assessment.fraction * 100).rounded()))% da cota incluída usada. Ela renova em \(assessment.remainingDays) dia(s).", "\(Int((assessment.fraction * 100).rounded()))% of the included usage used. It renews in \(assessment.remainingDays) day(s).")
                    : QuotaMessages.cycleAlertBody(used: MenuBarPresentation.money(Double(assessment.spentMicros)), goal: MenuBarPresentation.money(Double(assessment.targetMicros)))))
            }
        }
        if preferences.notifyDaily, assessment.dailyDataFresh, let spent = assessment.todaySpentMicros, let allowance = assessment.dailyLimitMicros,
           spent > 0, Double(spent) >= allowance * preferences.dailyAlertPercent / 100 {
            let suffix = preferences.dailyAlertPercent < 100 ? String(format: ":%.4f", preferences.dailyAlertPercent) : ""
            let id = "daily:\(limitKey):\(assessment.dayKey)" + suffix
            if !delivered.contains(id) {
                result.append(BudgetAlert(id: id, kind: .daily, title: QuotaMessages.alertTitle("Cursor", daily: true), body: QuotaMessages.dailyAlertBody(used: MenuBarPresentation.money(Double(spent)), threshold: MenuBarPresentation.money(allowance * preferences.dailyAlertPercent / 100), allowance: MenuBarPresentation.money(allowance))))
            }
        }
        return result
    }
}
