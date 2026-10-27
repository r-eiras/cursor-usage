import Foundation

// Model-level alerts read the imported CSV events: a model's first use, a model spending faster than the costliest
// model usually does, and limits the user sets for chosen models. None of them is a Cursor limit; the plan's
// allowance is shared by every model.
enum ModelAlerts {
    static let window: TimeInterval = 900
    static let history: TimeInterval = 14 * 86400
    static let minimumWindows = 4
    // Bursts under a dollar are too small to be worth a notification, however fast they are relatively.
    static let minimumBurstMicros: Int64 = 1_000_000

    struct Baseline: Equatable { let model: String; let typicalMicros: Int64; let costPerRequestMicros: Int64 }
    struct Evaluation { let alerts: [BudgetAlert]; let known: Set<String> }

    // The usual 15-minute spend of each model: the median of the windows in which it was used, so one burst cannot
    // become the norm. Models used in fewer windows have no baseline yet. Sorted from the costliest.
    static func baselines(_ events: [UsageEvent], before cutoff: Date) -> [Baseline] {
        let start = cutoff.addingTimeInterval(-history)
        var windows: [String: [Int64: Int64]] = [:], requests: [String: (cost: Int64, count: Int64)] = [:]
        for event in events where event.date >= start && event.date < cutoff {
            windows[event.model, default: [:]][Int64(floor(event.date.timeIntervalSince1970 / window)), default: 0] += event.costMicros
            let total = requests[event.model] ?? (0, 0); requests[event.model] = (total.cost + event.costMicros, total.count + 1)
        }
        return windows.compactMap { model, slots -> Baseline? in
            let sums = slots.values.filter { $0 > 0 }.sorted()
            guard sums.count >= minimumWindows, let total = requests[model] else { return nil }
            let median = sums.count % 2 == 1 ? sums[sums.count / 2] : (sums[sums.count / 2 - 1] + sums[sums.count / 2]) / 2
            return Baseline(model: model, typicalMicros: median, costPerRequestMicros: total.count > 0 ? total.cost / total.count : 0)
        }.sorted { $0.typicalMicros == $1.typicalMicros ? $0.model < $1.model : $0.typicalMicros > $1.typicalMicros }
    }

    // `known` is nil until the first import: that one only learns which models are in use, since announcing all of
    // them at once would be noise. The returned set always includes every model seen, alerts on or off.
    static func evaluate(dataset: UsageDataset, preferences: AppPreferences, known: Set<String>?, cycleStart: Date?, now: Date,
                         calendar: Calendar = .current, delivered: Set<String>) -> Evaluation {
        let money = { (micros: Int64) in MenuBarPresentation.money(Double(micros)) }
        let models = Set(dataset.events.map(\.model))
        var alerts: [BudgetAlert] = []
        if preferences.notifyNewModel, let known {
            for model in models.subtracting(known).sorted() {
                let spent = dataset.events.filter { $0.model == model }.reduce(Int64(0)) { $0 + $1.costMicros }
                alerts.append(BudgetAlert(id: "model-new:\(model)", kind: .newModel, title: L("Modelo novo em uso: \(model)", "New model in use: \(model)"),
                    body: L("\(money(spent)) até agora. Você pode definir um limite para ele nos avisos por modelo.", "\(money(spent)) so far. You can set a limit for it in per-model alerts.")))
            }
        }
        // Rates and limits need current data; an old import must not raise or repeat them.
        guard now.timeIntervalSince(dataset.fetchedAt) <= preferences.freshnessInterval else { return Evaluation(alerts: alerts, known: (known ?? []).union(models)) }
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        let dayKey = formatter.string(from: now)
        if preferences.notifyModelRate {
            let end = dataset.fetchedAt, start = end.addingTimeInterval(-window)
            if let reference = baselines(dataset.events, before: start).first, reference.typicalMicros > 0 {
                var bursts: [String: (cost: Int64, count: Int64)] = [:]
                for event in dataset.events where event.date > start && event.date <= end {
                    let total = bursts[event.model] ?? (0, 0); bursts[event.model] = (total.cost + event.costMicros, total.count + 1)
                }
                for (model, burst) in bursts.sorted(by: { $0.key < $1.key }) where burst.cost >= minimumBurstMicros {
                    let ratio = Double(burst.cost) / Double(reference.typicalMicros)
                    let id = "model-rate:\(model):\(dayKey)"
                    guard ratio >= 1 + Double(preferences.modelRatePercent) / 100, !delivered.contains(id) else { continue }
                    let over = Int(((ratio - 1) * 100).rounded())
                    let usual = money(reference.typicalMicros), spent = money(burst.cost)
                    if model == reference.model {
                        alerts.append(BudgetAlert(id: id, kind: .modelRate, title: L("\(model) está gastando \(over)% acima do normal", "\(model) is spending \(over)% above its usual rate"),
                            body: L("\(spent) nos últimos 15 min. Ele costuma gastar \(usual) em 15 min.", "\(spent) in the last 15 min. It usually spends \(usual) in 15 min.")))
                        continue
                    }
                    var body = L("\(spent) nos últimos 15 min. Seu \(reference.model) costuma gastar \(usual).", "\(spent) in the last 15 min. Your \(reference.model) usually spends \(usual).")
                    if reference.costPerRequestMicros > 0, burst.count > 0 {
                        let perRequest = Double(burst.cost) / Double(burst.count) / Double(reference.costPerRequestMicros)
                        let times = localizedDecimal(String(format: "%.1f", perRequest))
                        if perRequest >= 1.5 { body += L(" Cada requisição custa \(times)× a do \(reference.model).", " Each request costs \(times)× one of \(reference.model).") }
                    }
                    alerts.append(BudgetAlert(id: id, kind: .modelRate, title: L("\(model) está gastando \(over)% acima do seu modelo mais caro", "\(model) is spending \(over)% above your costliest model"), body: body))
                }
            }
        }
        let today = calendar.startOfDay(for: now)
        let cycle = cycleStart ?? calendar.dateInterval(of: .month, for: now)!.start
        for monitor in preferences.monitoredModels {
            let events = dataset.events.filter { $0.model == monitor.model && $0.date <= now }
            let daySpend = events.filter { $0.date >= today }.reduce(Int64(0)) { $0 + $1.costMicros }
            let cycleSpend = events.filter { $0.date >= cycle }.reduce(Int64(0)) { $0 + $1.costMicros }
            if let limit = monitor.dailyLimitMicros, limit > 0, daySpend >= limit, !delivered.contains("model-day:\(monitor.model):\(dayKey):\(limit)") {
                alerts.append(BudgetAlert(id: "model-day:\(monitor.model):\(dayKey):\(limit)", kind: .modelLimit,
                    title: L("\(monitor.model) passou de \(money(limit)) hoje", "\(monitor.model) passed \(money(limit)) today"),
                    body: L("\(money(daySpend)) no dia. Sua meta para este modelo é \(money(limit)).", "\(money(daySpend)) today. Your goal for this model is \(money(limit)).")))
            }
            let cycleKey = "\(Int(cycle.timeIntervalSince1970))"
            if let limit = monitor.cycleLimitMicros, limit > 0, cycleSpend >= limit, !delivered.contains("model-cycle:\(monitor.model):\(cycleKey):\(limit)") {
                alerts.append(BudgetAlert(id: "model-cycle:\(monitor.model):\(cycleKey):\(limit)", kind: .modelLimit,
                    title: L("\(monitor.model) passou de \(money(limit)) no ciclo", "\(monitor.model) passed \(money(limit)) this cycle"),
                    body: L("\(money(cycleSpend)) neste ciclo. Sua meta para este modelo é \(money(limit)).", "\(money(cycleSpend)) this cycle. Your goal for this model is \(money(limit)).")))
            }
        }
        return Evaluation(alerts: alerts, known: (known ?? []).union(models))
    }
}
