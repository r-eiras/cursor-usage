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
    case detailed, compact, iconsOnly
    var title: String {
        switch self { case .detailed: return L("Detalhada", "Detailed"); case .compact: return L("Compacta", "Compact"); case .iconsOnly: return L("Somente logos", "Logos only") }
    }
}
enum MenuIconStyle: String, Codable, CaseIterable {
    case app, cursor
    var title: String { self == .app ? "Cursor Usage" : "Cursor" }
}
enum MenuOpenBehavior: String, Codable, CaseIterable {
    case hoverAndClick, clickOnly
    var title: String {
        self == .hoverAndClick ? L("Ao passar o mouse ou clicar", "On hover or click") : L("Somente ao clicar", "On click only")
    }
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
    var menuIconStyle: MenuIconStyle { get { storedMenuIconStyle ?? .app } set { storedMenuIconStyle = newValue } }
    var showDetailedLabels: Bool { get { storedShowDetailedLabels ?? true } set { storedShowDetailedLabels = newValue } }
    var menuOpenBehavior: MenuOpenBehavior { get { storedMenuOpenBehavior ?? .hoverAndClick } set { storedMenuOpenBehavior = newValue } }
    var syncInterval: SyncInterval { get { storedSyncInterval == .fiveMinutes ? .standard : storedSyncInterval ?? .standard } set { storedSyncInterval = newValue } }
    var menuBarDensity: MenuBarDensity { get { storedMenuBarDensity ?? .detailed } set { storedMenuBarDensity = newValue } }
    var cursorUsageBasis: UsageDisplayBasis { get { storedCursorUsageBasis ?? .used } set { storedCursorUsageBasis = newValue } }
    var dailyAlertPercent: Double { get { storedDailyAlertPercent ?? 100 } set { storedDailyAlertPercent = newValue.isFinite ? min(100, max(1, newValue)) : 100 } }
    var notifyRenewal: Bool { get { storedNotifyRenewal ?? false } set { storedNotifyRenewal = newValue } }
    var language: AppLanguage { get { storedLanguage ?? .system } set { storedLanguage = newValue } }
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
    var fraction: Double { Double(spentMicros) / Double(targetMicros) }
    var overDailyLimit: Bool { guard let todaySpentMicros, let dailyLimitMicros else { return false }; return Double(todaySpentMicros) > dailyLimitMicros }
}

enum BudgetEngine {
    static func assess(quota: UsageSnapshot, dataset: UsageDataset?, preferences: AppPreferences, now: Date, calendar: Calendar = .current) -> BudgetAssessment? {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let reset = calendar.date(from: utc.dateComponents([.year, .month, .day], from: quota.resetDate)),
              let start = calendar.date(byAdding: .month, value: -1, to: reset), start <= now, reset > now else { return nil }
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
    static func money(_ micros: Double) -> String {
        let formatter = NumberFormatter(); formatter.locale = AppLanguage.locale; formatter.numberStyle = .currency; formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: micros / 1_000_000)) ?? "—"
    }
    static func make(preferences: AppPreferences, quota: UsageSnapshot?, dataset: UsageDataset?, now: Date, calendar: Calendar = .current, assessment: BudgetAssessment? = nil) -> MenuBarPresentation {
        let budget = assessment ?? quota.flatMap { BudgetEngine.assess(quota: $0, dataset: dataset, preferences: preferences, now: now, calendar: calendar) }
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
        let title: String
        switch preferences.menuBarDensity {
        case .detailed:
            let today = preferences.showDetailedLabels ? dailyContent + L(" Hoje", " Today") : dailyContent
            let cycle = preferences.showDetailedLabels ? cycleContent + L(" Ciclo", " Cycle") : cycleContent
            title = "\(today) · \(cycle)"
        case .compact: title = cycleContent
        case .iconsOnly: title = ""
        }
        return MenuBarPresentation(title: title,
            tooltip: "\(L("Hoje", "Today")): \(dailyContent) \(qualifier)\n\(L("Cota diária calculada", "Calculated daily allowance")): \(freshDaily ? budget?.dailyLimitMicros.map(money) ?? "—" : "—")\n\(L("Ciclo da assinatura", "Subscription cycle")): \(amount) \(qualifier)\n\(percent) \(L("do limite do ciclo", "of the cycle limit")): \(denominator.map(money) ?? L("indisponível", "unavailable"))\n\(preferences.personalBudgetEnabled ? L("Referência: sua meta pessoal", "Reference: your personal goal") : L("Referência: cota oficial", "Reference: official quota"))", fraction: fraction)
    }
}

struct BudgetAlert {
    enum Kind { case cycle, daily, renewal, window }
    let id: String
    let kind: Kind
    let title: String
    let body: String
}
enum BudgetAlerts {
    static func candidates(assessment: BudgetAssessment, preferences: AppPreferences, delivered: Set<String>) -> [BudgetAlert] {
        var result: [BudgetAlert] = []
        let limitKey = "\(assessment.cycleKey):\(assessment.targetMicros)"
        if preferences.notifyCycle && assessment.fraction * 100 >= Double(preferences.alertPercent) {
            let id = "cycle:\(limitKey):\(preferences.alertPercent)"
            if !delivered.contains(id) {
                result.append(BudgetAlert(id: id, kind: .cycle, title: QuotaMessages.alertTitle("Cursor"), body: QuotaMessages.cycleAlertBody(used: MenuBarPresentation.money(Double(assessment.spentMicros)), goal: MenuBarPresentation.money(Double(assessment.targetMicros)))))
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

