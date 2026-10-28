import Foundation

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let now = ISO8601DateFormatter().date(from: "2026-10-27T18:00:00Z")!
func event(_ model: String, _ dollars: Double, _ date: Date) -> UsageEvent {
    UsageEvent(date: date, model: model, kind: "Included", costMicros: Int64(dollars * 1_000_000), inputTokens: nil, cacheWriteTokens: nil, cacheReadTokens: nil, outputTokens: nil, totalTokens: nil)
}
// Past usage: one session a day in its own 15-minute window, over six days.
var history: [UsageEvent] = []
for day in 1...6 {
    let session = now.addingTimeInterval(-Double(day) * 86400)
    history += [event("claude-opus", 5, session), event("claude-opus", 5, session.addingTimeInterval(60))]
    history.append(event("claude-sonnet", day == 3 ? 100 : 4, session.addingTimeInterval(3600)))
    history.append(event("auto", 1, session.addingTimeInterval(7200)))
}
history += (1...3).map { event("gpt-codex", 50, now.addingTimeInterval(-Double($0) * 86400 - 10800)) }
func dataset(_ events: [UsageEvent], fetched: Date = now.addingTimeInterval(-60)) -> UsageDataset {
    UsageDataset(events: events, coverageStart: now.addingTimeInterval(-30 * 86400), coverageEnd: now, fetchedAt: fetched, accountDigest: "synthetic")
}
func evaluate(_ events: [UsageEvent], _ preferences: AppPreferences = AppPreferences(), known: Set<String>? = ["claude-opus", "claude-sonnet", "auto", "gpt-codex", "gemini-argon"],
              fetched: Date = now.addingTimeInterval(-60), cycleStart: Date? = nil, delivered: Set<String> = [], saved: [String: ModelAlerts.Baseline] = [:]) -> ModelAlerts.Evaluation {
    ModelAlerts.evaluate(dataset: dataset(events, fetched: fetched), preferences: preferences, known: known, cycleStart: cycleStart, now: now, calendar: calendar, delivered: delivered, saved: saved)
}

for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    let baselines = ModelAlerts.baselines(history, before: now.addingTimeInterval(-900))
    check(baselines.first == ModelAlerts.Baseline(model: "claude-opus", typicalMicros: 10_000_000, costPerRequestMicros: 5_000_000), "The costliest usual 15-minute spend leads, with its cost per request")
    check(baselines.first { $0.model == "claude-sonnet" }?.typicalMicros == 4_000_000, "A one-off spike does not become a model's norm")
    check(!baselines.contains { $0.model == "gpt-codex" }, "A model used in too few windows has no baseline yet")

    let burst = history + [event("gemini-argon", 15, now.addingTimeInterval(-300))]
    let firstImport = evaluate(burst, known: nil)
    check(!firstImport.alerts.contains { $0.kind == .newModel } && firstImport.known.count == 5, "The first import learns the models in use without announcing them")
    let newModel = evaluate(burst, known: ["claude-opus", "claude-sonnet", "auto", "gpt-codex"]).alerts.filter { $0.kind == .newModel }
    check(newModel.map(\.id) == ["model-new:gemini-argon"] && newModel[0].body.contains(MenuBarPresentation.money(15_000_000)), "A model seen for the first time is announced with what it has spent")
    var quiet = AppPreferences(); quiet.notifyNewModel = false
    let silent = evaluate(burst, quiet, known: ["claude-opus"])
    check(!silent.alerts.contains { $0.kind == .newModel } && silent.known.contains("gemini-argon"), "With the alert off, new models are still remembered, so turning it on later is not noisy")

    let rate = evaluate(burst).alerts.filter { $0.kind == .modelRate }
    check(rate.count == 1 && rate[0].id == "model-rate:gemini-argon:2026-10-27", "Spending 50% above the costliest model's usual 15 minutes raises one alert")
    check(rate[0].title.contains("gemini-argon") && rate[0].title.contains("50%") && rate[0].title.contains(L("mais caro", "costliest")), "The title names the model and how far above it is")
    check(rate[0].body.contains("claude-opus") && rate[0].body.contains(MenuBarPresentation.money(10_000_000)) && rate[0].body.contains(L("3,0×", "3.0×")), "The body gives the usual rate it is compared with and the higher price per request")
    var strict = AppPreferences(); strict.modelRatePercent = 60
    check(evaluate(burst, strict).alerts.allSatisfy { $0.kind != .modelRate }, "The threshold is configurable")
    check(evaluate(burst, delivered: ["model-rate:gemini-argon:2026-10-27"]).alerts.allSatisfy { $0.kind != .modelRate }, "A model's rate alert is sent once a day")
    check(evaluate(history + [event("gemini-argon", 0.9, now.addingTimeInterval(-300))], strict).alerts.allSatisfy { $0.kind != .modelRate }, "Bursts under a dollar never notify")
    let opusBurst = evaluate(history + [event("claude-opus", 16, now.addingTimeInterval(-200))]).alerts.filter { $0.kind == .modelRate }
    check(opusBurst.count == 1 && opusBurst[0].title.contains(L("acima do normal", "above its usual rate")), "The costliest model is compared with its own usual rate")
    let stale = evaluate(burst, known: ["claude-opus"], fetched: now.addingTimeInterval(-7200)).alerts
    check(!stale.contains { $0.kind == .modelRate } && stale.contains { $0.kind == .newModel }, "Old data never raises a rate alert, but a first use is still news")
    check(evaluate([event("gemini-argon", 15, now.addingTimeInterval(-300))]).alerts.allSatisfy { $0.kind != .modelRate }, "Without enough history there is nothing to compare with")

    var dollars = AppPreferences(); dollars.modelRateUnit = .amount; dollars.modelRateAmountMicros = 5_000_000
    let byAmount = evaluate(burst, dollars).alerts.filter { $0.kind == .modelRate }
    check(byAmount.count == 1 && byAmount[0].title.contains(MenuBarPresentation.money(5_000_000)), "A dollar threshold alerts at the reference's usual spend plus that amount, and says how much above")
    dollars.modelRateAmountMicros = 5_010_000; check(evaluate(burst, dollars).alerts.allSatisfy { $0.kind != .modelRate }, "Just under the dollar threshold stays quiet")
    var chosen = AppPreferences(); chosen.modelRateReference = "claude-sonnet"
    let bySonnet = evaluate(history + [event("auto", 7, now.addingTimeInterval(-300))], chosen).alerts.filter { $0.kind == .modelRate }
    check(bySonnet.count == 1 && bySonnet[0].title.contains("claude-sonnet") && !bySonnet[0].title.contains(L("mais caro", "costliest")), "A chosen reference replaces the costliest model and is named")
    check(evaluate(history + [event("auto", 7, now.addingTimeInterval(-300))]).alerts.allSatisfy { $0.kind != .modelRate }, "The same burst is normal against the costliest model")
    let learned = evaluate(burst).baselines
    check(learned["claude-sonnet"]?.typicalMicros == 4_000_000 && learned["claude-opus"]?.typicalMicros == 10_000_000, "Each model's pace is returned to be saved")
    let withoutSonnet = history.filter { $0.model != "claude-sonnet" } + [event("auto", 7, now.addingTimeInterval(-300))]
    check(evaluate(withoutSonnet, chosen).alerts.allSatisfy { $0.kind != .modelRate }, "Without its saved pace, a reference that left the history cannot be compared")
    let fromSaved = evaluate(withoutSonnet, chosen, saved: learned)
    check(fromSaved.alerts.filter { $0.kind == .modelRate }.count == 1 && fromSaved.baselines["claude-sonnet"] == learned["claude-sonnet"], "A reference that left the history keeps its saved pace")
    check(evaluate(burst, fetched: now.addingTimeInterval(-7200), saved: learned).baselines == learned, "Old data leaves the saved paces untouched")

    var monitored = AppPreferences(); monitored.notifyModelRate = false
    monitored.monitoredModels = [MonitoredModel(model: "gemini-argon", dailyLimitMicros: 20_000_000, cycleLimitMicros: 30_000_000)]
    check(evaluate(burst, monitored).alerts.allSatisfy { $0.kind != .modelLimit }, "Below its limits a monitored model stays quiet")
    let today = burst + [event("gemini-argon", 6, now.addingTimeInterval(-120))]
    let daily = evaluate(today, monitored).alerts.filter { $0.kind == .modelLimit }
    check(daily.map(\.id) == ["model-day:gemini-argon:2026-10-27:20000000"] && daily[0].body.contains(MenuBarPresentation.money(21_000_000)), "Passing the daily limit notifies with the day's spend")
    check(evaluate(today, monitored, delivered: Set(daily.map(\.id))).alerts.allSatisfy { $0.kind != .modelLimit }, "The daily limit alert is not repeated")
    let cycle = today + [event("gemini-argon", 10, now.addingTimeInterval(-3 * 86400))]
    let cycleAlerts = evaluate(cycle, monitored, cycleStart: now.addingTimeInterval(-10 * 86400), delivered: Set(daily.map(\.id))).alerts.filter { $0.kind == .modelLimit }
    check(cycleAlerts.count == 1 && cycleAlerts[0].id.hasPrefix("model-cycle:gemini-argon:"), "Passing the cycle limit counts every day of the cycle")
    check(evaluate(cycle, monitored, cycleStart: now.addingTimeInterval(-86400 / 2), delivered: Set(daily.map(\.id))).alerts.allSatisfy { $0.kind != .modelLimit }, "Spending before the cycle started does not count")
    check(evaluate(today, monitored, known: nil).alerts.contains { $0.kind == .modelLimit }, "Limits work from the first import")
}

let defaults = AppPreferences()
check(defaults.notifyNewModel && defaults.notifyModelRate && defaults.modelRatePercent == 50 && defaults.monitoredModels.isEmpty, "Model alerts need no setup: on, at 50%, with no monitored models")
var clamped = AppPreferences(); clamped.modelRatePercent = 0; check(clamped.modelRatePercent == 1, "Any percentage from 1% can be set")
clamped.modelRatePercent = 900; check(clamped.modelRatePercent == 900, "Large percentages are kept")
clamped.modelRatePercent = 50_000; check(clamped.modelRatePercent == 10_000, "The threshold still has a ceiling")
var saved = AppPreferences(); saved.notifyNewModel = false; saved.modelRatePercent = 80
saved.monitoredModels = [MonitoredModel(model: "gemini-argon", dailyLimitMicros: 20_000_000, cycleLimitMicros: nil)]
let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(saved))
check(!restored.notifyNewModel && restored.modelRatePercent == 80 && restored.monitoredModels == saved.monitoredModels, "Model alert choices survive a restart")
let legacy = try JSONDecoder().decode(AppPreferences.self, from: Data(#"{"menuMode":"amount","showIcon":true,"personalBudgetEnabled":false,"personalBudgetMicros":0,"notifyCycle":true,"alertPercent":80,"notifyDaily":false,"alertSound":false}"#.utf8))
check(legacy.notifyCycle && legacy.notifyNewModel && legacy.monitoredModels.isEmpty, "Older settings files upgrade without losing choices")
print("PASS: model alerts for first use, spending above the costliest model, monitored limits and their preferences")
