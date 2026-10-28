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
        let sort = card.subviews.compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 3 && $0.label(forSegment: 1) == "Tokens" }!
        let scroll = card.subviews.compactMap { $0 as? NSScrollView }.first!
        func firstModel() -> String { scroll.documentView?.subviews.first?.accessibilityLabel() ?? "" }
        check(firstModel().contains("expensive-model"), "Cost sorting starts with the most expensive model")
        sort.selectedSegment = 1; _ = sort.sendAction(sort.action, to: sort.target)
        check(firstModel().contains("token-heavy-model"), "Tokens sorting changes the visible model order")
        sort.selectedSegment = 0; _ = sort.sendAction(sort.action, to: sort.target)
        check(firstModel().contains("expensive-model"), "Cost sorting restores the highest-cost order")
        check(sort.label(forSegment: 2) == L("Ritmo", "Pace"), "A third order sorts by pace")
        card.setPaces(["token-heavy-model": 9_000_000, "expensive-model": 2_000_000])
        sort.selectedSegment = 2; _ = sort.sendAction(sort.action, to: sort.target)
        check(firstModel().contains("token-heavy-model"), "Pace sorting puts the fastest usual 15 minutes first")
        check(scroll.documentView?.subviews.first?.accessibilityHelp()?.contains(QuotaStyle.money(9_000_000)) == true, "Each row carries its pace into the detail")
        card.setPaces(["expensive-model": 12_000_000]); check(firstModel().contains("expensive-model"), "New paces reorder the list; models without a pace go last")
        sort.selectedSegment = 0; _ = sort.sendAction(sort.action, to: sort.target)
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
        check(lines.contains { $0 == (L("Ritmo típico em 15 min", "Usual pace per 15 min"), L("pouco uso ainda", "not enough use yet")) }, "Without a pace the detail says there is not enough use yet")
        check(ModelDetailView.lines(for: expensive, share: 0.9, pace: 3_000_000).contains { $0 == (L("Ritmo típico em 15 min", "Usual pace per 15 min"), QuotaStyle.money(3_000_000)) }, "The detail shows the model's usual 15 minutes")
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
        let status = NSButton(title: "", target: nil, action: nil)
        CursorMark.configure(status, title: "$12.30", showsIcon: false, updateBadge: true)
        let dot = (status.attributedTitle.string as NSString).range(of: CursorMark.updateBadge)
        check(status.title == "$12.30 ●" && status.attributedTitle.attribute(.foregroundColor, at: dot.location, effectiveRange: nil) as? NSColor == .controlAccentColor, "An available update adds an accent dot after the menu bar reading")
        CursorMark.configure(status, title: "$12.30", showsIcon: false); check(status.title == "$12.30", "The dot goes away once the update is installed")
        CursorMark.configure(status, title: "", showsIcon: true, updateBadge: true); check(status.title == "●" && status.image != nil, "With only the icon, the dot follows it without a leading space")
        check(CursorMark.usageColor(nil) == nil && CursorMark.usageColor(0.29) == nil && CursorMark.usageColor(0.3) == .systemYellow && CursorMark.usageColor(0.59) == .systemYellow
              && CursorMark.usageColor(0.6) == .systemOrange && CursorMark.usageColor(0.89) == .systemOrange && CursorMark.usageColor(0.9) == .systemRed && CursorMark.usageColor(1.4) == .systemRed,
              "The icon is plain below 30%, yellow to 60%, orange to 90% and red from there")
        for style in MenuIconStyle.allCases {
            let plain = style == .app ? CursorMark.appImage() : CursorMark.image()
            CursorMark.configure(status, title: "$1", showsIcon: true, style: style, usage: 0.1); check(status.image === plain, "Under 30% the \(style) icon keeps its normal look")
            CursorMark.configure(status, title: "$1", showsIcon: true, style: style, usage: 0.95); let red = status.image
            check(red != nil && red !== plain && red?.isTemplate == false, "Near the limit the \(style) icon is drawn in color")
            CursorMark.configure(status, title: "$1", showsIcon: true, style: style, usage: 0.97); check(status.image === red, "Readings at the same level reuse the same image")
            CursorMark.configure(status, title: "$1", showsIcon: true, style: style, usage: 0.7); check(status.image !== red, "Crossing a level changes the color")
        }
    }
    final class Flipped: NSView { override var isFlipped: Bool { true } }
    let list = OverlayScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)); list.documentView = Flipped(frame: NSRect(x: 0, y: 0, width: 100, height: 300)); list.tile()
    check(list.showsMoreBelow && (list.isFlipped ? list.moreBelow.frame.maxY == list.bounds.maxY : list.moreBelow.frame.minY == 0) && list.moreBelow.frame.width == 100, "Content below the visible area shows a fade with an arrow at the bottom")
    list.contentView.scroll(to: NSPoint(x: 0, y: 200)); list.reflectScrolledClipView(list.contentView)
    check(!list.showsMoreBelow, "At the end of the list the indicator goes away")
    list.contentView.scroll(to: NSPoint(x: 0, y: 50)); list.reflectScrolledClipView(list.contentView)
    check(list.showsMoreBelow, "Scrolling back up brings it back")
    list.documentView?.frame.size.height = 80; check(!list.showsMoreBelow, "Content that fits needs no indicator")
    check(list.moreBelow.hitTest(NSPoint(x: 50, y: 10)) == nil, "The indicator never blocks clicks on the rows under it")
    let pinned = OverlayScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)); pinned.scrollerStyle = .legacy
    check(pinned.scrollerStyle == .overlay, "Lists keep scrollers that fade out, even when macOS prefers visible ones")
    let window = OverlayScrollView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)); window.keepsScrollerVisible = true; window.scrollerStyle = .overlay
    check(window.scrollerStyle == .legacy, "A scroll view can keep its bar on screen instead")
    check(window.verticalScroller is ThinScroller && type(of: window.verticalScroller!).scrollerWidth(for: .regular, scrollerStyle: .legacy) <= 10, "The bar that stays is thin")
    print("PASS: model sorting controls, current month, removal of the custom period, model detail and fading scrollers")
}
