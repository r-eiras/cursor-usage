import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
MainActor.assumeIsolated {
    _ = NSApplication.shared
    let now = instant("2026-10-22T18:00:00Z")
    let csv = """
    Date,User,Kind,Model,Total Tokens,Cost
    2026-10-22T16:00:00Z,self@example.test,Included,expensive-model,100,10.00
    2026-10-22T17:00:00Z,self@example.test,Included,token-heavy-model,1000,1.00
    """
    let dataset = try! UsageCSV.parse(csv, coverage: DateInterval(start: instant("2026-10-01T00:00:00Z"), end: instant("2026-10-23T00:00:00Z")), fetchedAt: now)
    for language in [AppLanguage.portuguese, .english] {
        AppLanguage.current = language
        let card = QuotaCard(frame: NSRect(origin: .zero, size: QuotaCard.size))
        card.update(snapshot: nil, dataset: dataset, selection: PeriodSelection(), stale: false, message: "", analyticsMessage: "", now: now)
        card.showModels()
        let sort = card.subviews.compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 2 }!
        let scroll = card.subviews.compactMap { $0 as? NSScrollView }.first!
        func firstModel() -> String { scroll.documentView?.subviews.first?.accessibilityLabel() ?? "" }
        check(firstModel().contains("expensive-model"), "Cost sorting starts with the most expensive model")
        sort.selectedSegment = 1; _ = sort.sendAction(sort.action, to: sort.target)
        check(firstModel().contains("token-heavy-model"), "Tokens sorting changes the visible model order")
        sort.selectedSegment = 0; _ = sort.sendAction(sort.action, to: sort.target)
        check(firstModel().contains("expensive-model"), "Cost sorting restores the highest-cost order")
        let period = card.subviews.compactMap { $0 as? NSPopUpButton }.first!
        check(period.numberOfItems == 5 && !period.itemTitles.contains(L("Personalizado", "Custom")), "The card has no custom period option")
        var selected: UsagePeriod?
        card.onPeriod = { selected = $0 }
        period.selectItem(at: UsagePeriod.allCases.firstIndex(of: .month)!); _ = period.sendAction(period.action, to: period.target)
        check(selected == .month && period.title == L("Mês corrente", "Current month"), "The current month selection reaches the app callback")
    }
    let report = AnalyticsEngine.report(dataset: dataset, selection: PeriodSelection(), quota: nil, now: now)!
    let expensive = report.models.first { $0.model == "expensive-model" }!
    for language in [AppLanguage.portuguese, .english] {
        AppLanguage.current = language
        let lines = ModelDetailView.lines(for: expensive, share: 0.9)
        check(lines.first?.1.contains(QuotaStyle.money(10_000_000)) == true && lines.contains { $0.0 == L("Custo médio por requisição", "Average cost per request") }, "The detail shows the cost, its share and the average per request")
        check(lines.contains { $0.0 == L("Leitura de cache", "Cache read") } && lines.contains { $0.0 == L("Saída", "Output") }, "The detail shows every token kind")
    }
    let detail = ModelDetailView(frame: .zero)
    let short = detail.show(expensive, share: 0.9)
    let long = detail.show(ModelUsage(model: String(repeating: "very-long-model-name-", count: 4), costMicros: 1, events: 1), share: 0.1)
    check(short.width == ModelDetailView.width && long.height > short.height, "A long name wraps inside the detail instead of being cut")
    for language in [AppLanguage.portuguese, .english] {
        AppLanguage.current = language
        let card = QuotaCard(frame: NSRect(origin: .zero, size: QuotaCard.size))
        let button = card.subviews.compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "update" }!
        check(button.isHidden, "No update button while the app is current")
        var clicked = 0; card.onUpdate = { clicked += 1 }
        card.setUpdate("9.1.0", installing: false)
        check(!button.isHidden && button.isEnabled && button.title == L("Atualizar para 9.1.0", "Update to 9.1.0"), "An available update stays visible in the card")
        button.performClick(nil); check(clicked == 1, "The card button starts the update")
        card.setUpdate("9.1.0", installing: true)
        check(!button.isEnabled && button.title == L("Atualizando para 9.1.0…", "Updating to 9.1.0…"), "While installing, the button shows progress and cannot start a second update")
        check(button.frame.maxX <= 186 && button.frame.minY >= 356, "The button takes the footer text's place, clear of the toolbar icons")
        card.setUpdate(nil, installing: false); check(button.isHidden, "Once installed, the button goes away")
    }
    let pinned = OverlayScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)); pinned.scrollerStyle = .legacy
    check(pinned.scrollerStyle == .overlay, "Lists keep scrollers that fade out, even when macOS prefers visible ones")
    print("PASS: model sorting controls, current month, removal of the custom period, model detail and fading scrollers")
}
