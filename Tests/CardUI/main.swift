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
    print("PASS: model sorting controls, current month and removal of the custom period in both languages")
}
