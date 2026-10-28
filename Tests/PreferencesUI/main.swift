import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
MainActor.assumeIsolated {
    _ = NSApplication.shared
    for language in [AppLanguage.english, .portuguese] {
        AppLanguage.current = language
        let controls = CursorAlertControls()
        var value = QuotaAlertDraft(); value.personalEnabled = true; value.personalLimit = 100
        value.cycleEnabled = true; value.dailyEnabled = true; value.dailyPercent = 50
        controls.present(value, officialLimit: 1000); controls.setAssessment(allowance: 10, todayUsed: 2, observedSince: nil)
        check(controls.subviews.compactMap { $0 as? NSSlider }.count == 2, "Cycle and daily sliders are available")
        let daily = controls.subviews.compactMap { $0 as? NSTextField }.first { $0.placeholderString == L("Após sincronizar", "After syncing") }!
        daily.stringValue = "5"; controls.controlTextDidChange(Notification(name: NSText.didChangeNotification, object: daily))
        check(controls.draft()?.dailyPercent == 50, "Daily amount follows the calculated allowance")
        daily.stringValue = "11"; controls.controlTextDidChange(Notification(name: NSText.didChangeNotification, object: daily))
        check(controls.draft() == nil, "Invalid daily amounts cannot be saved")
        let alertButtons = controls.subviews.compactMap { $0 as? NSButton }
        let personal = alertButtons.first { $0.title == L("Definir um limite pessoal de gastos", "Set a personal spending limit") }!
        let cycle = alertButtons.first { $0.title == L("Avisar ao consumir 80% do limite", "Notify at 80% of the limit") }!
        let dailyToggle = alertButtons.first { $0.title == L("Notificar ao atingir esta % da cota diária", "Notify at this % of the daily allowance") }!
        let currency = controls.subviews.compactMap { $0 as? NSTextField }.first { $0.stringValue == "US$" }!
        check(!currency.frame.intersects(dailyToggle.frame), "The daily currency label never overlaps the alert title in either language")
        check(abs(currency.frame.midY - daily.frame.midY) <= 2, "The daily currency label aligns with its amount field")
        let sound = alertButtons.first { $0.title == L("Tocar som junto às notificações", "Play a sound with notifications") }!
        let renewal = alertButtons.first { $0.title == L("Avisar quando uma cota for renovada", "Alert when a quota renews") }!
        let limit = controls.subviews.compactMap { $0 as? NSTextField }.first { $0.placeholderString == L("Ex.: 500,00", "E.g. 500.00") }!
        controls.present(QuotaAlertDraft(), officialLimit: 1000)
        check(!limit.isEnabled && !daily.isEnabled && !sound.isEnabled, "Opt-in controls start disabled")
        personal.performClick(nil); limit.stringValue = "0"
        controls.controlTextDidChange(Notification(name: NSText.didChangeNotification, object: limit))
        check(controls.draft() == nil, "Zero personal goals cannot be saved")
        limit.stringValue = L("500,50", "500.50")
        controls.controlTextDidChange(Notification(name: NSText.didChangeNotification, object: limit))
        cycle.performClick(nil); dailyToggle.performClick(nil); sound.performClick(nil); renewal.performClick(nil)
        let sliders = controls.subviews.compactMap { $0 as? NSSlider }
        sliders[0].integerValue = 75; _ = sliders[0].sendAction(sliders[0].action, to: sliders[0].target)
        sliders[1].doubleValue = 25; _ = sliders[1].sendAction(sliders[1].action, to: sliders[1].target)
        let alertDraft = controls.draft()!
        check(alertDraft.personalLimit == 500.50 && alertDraft.cyclePercent == 75 && alertDraft.dailyPercent == 25, "Goal and both sliders are reflected in the draft")
        check(alertDraft.cycleEnabled && alertDraft.dailyEnabled && alertDraft.sound && alertDraft.renewal, "All alert switches are reflected in the draft")
        check(daily.stringValue == L("2,50", "2.50"), "The daily slider updates its linked money field")
        let panel = PreferencesPanel(); panel.startupState = { .disabled }
        var saved: AppPreferences?
        panel.onSave = { saved = $0; return true }; panel.present(AppPreferences())
        let window = panel.window!, content = window.contentView!
        check(content.bounds.height <= 640, "Preferences fit the visible screen")
        let save = content.subviews.compactMap { $0 as? NSButton }.first { $0.title == L("Salvar", "Save") }!
        window.setContentSize(NSSize(width: 444, height: 400))
        check(save.frame.minY >= 0 && save.frame.maxY <= 44, "Save remains in the fixed footer")
        save.performClick(nil); check(saved != nil, "The preferences adapter saves valid Cursor choices")
        window.orderOut(nil)

        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let views = descendants(content)
        let pickers = views.compactMap { $0 as? NSPopUpButton }
        check(pickers.count == 7, "All menu, sync and language selectors are present")
        let mode = pickers[0], basis = pickers[1], density = pickers[2]
        let navigation = views.compactMap { $0 as? NSSegmentedControl }.first { $0.segmentCount == 3 }!
        for index in 0..<3 {
            navigation.selectedSegment = index; _ = navigation.sendAction(navigation.action, to: navigation.target)
        }
        navigation.selectedSegment = 0; _ = navigation.sendAction(navigation.action, to: navigation.target)
        func change(_ picker: NSPopUpButton, _ index: Int) { picker.selectItem(at: index); _ = picker.sendAction(picker.action, to: picker.target) }
        let boxes = views.compactMap { $0 as? NSButton }.filter { $0 is NSPopUpButton == false }
        check(!boxes.contains { $0.title == L("Mostrar período", "Show period") }, "Period labels are not a menu-bar preference")
        let showIcon = boxes.first { $0.title == L("Mostrar ícone", "Show icon") }!
        let cancel = boxes.first { $0.title == L("Cancelar", "Cancel") }!
        panel.present(AppPreferences())
        change(basis, 1); change(density, 2)
        check(!mode.isEnabled && !basis.isEnabled && !showIcon.isEnabled, "Logo-only mode disables controls without a visible effect")
        check(pickers[3].isEnabled, "Logo-only mode still offers hover or click opening")
        change(density, 1)
        check(mode.isEnabled && basis.isEnabled, "Returning to text restores the controls")
        change(mode, 2); change(basis, 0)
        change(pickers[3], 1); change(pickers[4], 1); change(pickers[5], 2); change(pickers[6], 2)
        showIcon.performClick(nil)
        saved = nil; save.performClick(nil)
        check(saved?.menuIconStyle == .cursor, "The Cursor icon choice is saved independently of the display mode")
        check(saved?.menuMode == .both && saved?.menuBarDensity == .compact, "Save commits the selected menu format and density")
        check(saved?.cursorUsageBasis == .used && saved?.syncInterval == .tenMinutes && saved?.language == .english, "Save commits basis, sync and language")
        check(saved?.menuOpenBehavior == .clickOnly, "Save commits the explicit click-only menu choice")
        check(saved?.showIcon == false, "Save commits icon visibility")
        panel.present(saved!); check(showIcon.state == .off, "Reopening restores icon visibility")
        saved = nil; change(mode, 0)
        panel.suspendForMenuBar()
        check(!window.isVisible && saved == nil, "Opening the quota card hides settings without saving")
        check(panel.resumeIfSuspended() && window.isVisible && mode.indexOfSelectedItem == 0, "Only an explicit settings action resumes the unsaved draft")
        cancel.performClick(nil)
        check(!panel.resumeIfSuspended(), "Cancel discards the suspended draft")
        check(saved == nil && !window.isVisible, "Cancel discards the draft")
        panel.present(AppPreferences()); panel.onSave = { _ in false }; save.performClick(nil)
        check(window.isVisible, "A failed save keeps the draft open")
        var previewReading = "first reading"
        panel.onPreview = { _ in previewReading }; panel.updateReadings()
        check(views.compactMap { $0 as? NSButton }.contains { $0.title == previewReading }, "Preview receives the current reading")
        previewReading = "new reading"; panel.updateReadings()
        check(views.compactMap { $0 as? NSButton }.contains { $0.title == previewReading }, "Preview updates after a background sync")
        panel.onPreview = { $0.menuBarDensity == .iconsOnly ? "" : "25%" }
        panel.present(AppPreferences())
        let preview = views.compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "menuBarPreview" }!
        check(preview.title == "25%" && preview.image != nil, "Preview includes the same icon and text as the menu bar")
        check(preview.image?.isTemplate == true, "The app icon adapts to the native menu bar contrast")
        change(pickers[4], 1); check(preview.image === CursorMark.image(), "The preview uses the selected Cursor logo")
        change(pickers[4], 0); check(preview.image === CursorMark.appImage(), "The preview uses the app's own quota mark")
        showIcon.performClick(nil); check(preview.image == nil, "Hiding the icon updates the preview immediately")
        let labels = boxes.first { $0.title == L("Mostrar rótulos Hoje e Ciclo", "Show Today and Cycle labels") }!
        check(labels.isEnabled, "Detailed display offers optional labels")
        labels.performClick(nil); saved = nil; panel.onSave = { saved = $0; return true }; save.performClick(nil)
        check(saved?.showDetailedLabels == false, "Save preserves the detailed label choice")
        change(density, 2)
        check(preview.title.isEmpty && preview.image != nil && !labels.isEnabled, "Logo-only preview matches the actual icon-only menu item")
        change(density, 1); check(!labels.isEnabled, "Compact mode has no daily labels to configure")
        panel.present(AppPreferences())
        let account = boxes.first { $0.title == L("Conta do Cursor", "Cursor account") }!
        var openedAccount = false; saved = nil
        panel.onConnect = { openedAccount = true }; account.performClick(nil)
        check(openedAccount && saved == nil && !window.isVisible, "Account access is separate from saving settings")
        check(panel.resumeIfSuspended(), "Account access preserves the settings draft")
        check(account.frame.minY < 40, "Account access is at the top of settings")
        panel.canDisconnect = { true }; panel.present(AppPreferences())
        var disconnected = false; panel.onDisconnect = { disconnected = true }
        let logout = views.compactMap { $0 as? NSButton }.first { $0.identifier?.rawValue == "disconnectAccount" }!
        logout.performClick(nil); check(disconnected, "The account logout control invokes its own action")
        var editing = AppPreferences(); editing.notifyDaily = true
        panel.onPreview = { $0.showDetailedLabels ? "0% Hoje · 42% Ciclo" : "0% · 42%" }
        panel.present(editing)
        let panelAlerts = views.compactMap { $0 as? CursorAlertControls }.first!
        panelAlerts.setAssessment(allowance: 10, todayUsed: 0, observedSince: nil)
        let dailyField = panelAlerts.subviews.compactMap { $0 as? NSTextField }.first { $0.placeholderString == L("Após sincronizar", "After syncing") }!
        dailyField.stringValue = "a"; panelAlerts.controlTextDidChange(Notification(name: NSText.didChangeNotification, object: dailyField))
        labels.performClick(nil)
        check(preview.title == "0% · 42%" && preview.image != nil, "An invalid alert draft never hides the menu preview when toggling labels")
        saved = nil; save.performClick(nil); check(saved == nil, "Invalid alerts still prevent saving without blocking the menu preview")
        let reportIssue = views.compactMap { $0 as? NSButton }.first { $0.title == L("Reportar problema…", "Report an issue…") }!
        var reported = false; panel.onReportIssue = { reported = true }; reportIssue.performClick(nil)
        check(reported, "The report issue button reaches its action without submitting anything")
        let updates = views.compactMap { $0 as? NSButton }.first { $0.title == L("Verificar atualizações…", "Check for Updates…") }!
        panel.setUpdateChecking(true); check(!updates.isEnabled, "Checking updates prevents duplicate requests")
        panel.setUpdateChecking(false); check(updates.isEnabled, "Finishing restores the update action")
        window.orderOut(nil)
    }
    for language in [AppLanguage.english, .portuguese] {
        AppLanguage.current = language
        let models = ModelAlertControls()
        var resized = 0; models.onResize = { resized += 1 }
        let choices = [ModelAlertControls.Choice(model: "claude-opus", cycleSpendMicros: 90_000_000, isNew: false), ModelAlertControls.Choice(model: "gemini-argon", cycleSpendMicros: 15_000_000, isNew: true)]
        models.present(ModelAlertControls.Draft(), choices: choices)
        check(models.draft() == ModelAlertControls.Draft(), "Model alerts start on at 50% with nothing monitored")
        let emptyHeight = models.frame.height
        models.monitor("gemini-argon"); models.monitor("gemini-argon")
        check(models.monitoredModels == ["gemini-argon"] && models.frame.height > emptyHeight && resized > 0, "Monitoring a model adds one row and grows the section")
        func fields() -> [NSTextField] { models.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }.filter { $0.isEditable } }
        check(fields().count == 2, "Each monitored model has a daily and a cycle limit")
        fields()[0].stringValue = L("20,50", "20.50"); fields()[1].stringValue = ""
        check(models.draft()?.monitored == [MonitoredModel(model: "gemini-argon", dailyLimitMicros: 20_500_000, cycleLimitMicros: nil)], "An empty limit means none, and amounts accept the local decimal mark")
        fields()[1].stringValue = "0"
        check(models.draft() == nil, "A zero limit cannot be saved")
        fields()[1].stringValue = "abc"; check(models.draft() == nil, "Text that is not an amount cannot be saved")
        func spentLabels() -> [String] { models.subviews.flatMap(\.subviews).compactMap { $0 as? NSTextField }.filter { !$0.isEditable }.map(\.stringValue) }
        fields()[1].stringValue = ""
        check(spentLabels().contains(MenuBarPresentation.money(15_000_000)), "A monitored row shows the model's cycle spend")
        models.updateSpend([ModelAlertControls.Choice(model: "gemini-argon", cycleSpendMicros: 42_000_000, isNew: false)])
        check(spentLabels().contains(MenuBarPresentation.money(42_000_000)) && !spentLabels().contains(MenuBarPresentation.money(15_000_000)), "A sync while settings is open updates the row's cycle spend")
        check(models.draft()?.monitored == [MonitoredModel(model: "gemini-argon", dailyLimitMicros: 20_500_000, cycleLimitMicros: nil)], "Updating the spend keeps the limits being typed")
        fields()[1].stringValue = "50"
        let rate = models.subviews.compactMap { $0 as? NSButton }.first { $0.title.contains("50%") }!
        let slider = models.subviews.compactMap { $0 as? NSSlider }.first!
        slider.integerValue = 80; _ = slider.sendAction(slider.action, to: slider.target)
        check(rate.title.contains("80%") && models.draft()?.ratePercent == 80, "The threshold slider updates its title and the draft")
        rate.performClick(nil); check(!slider.isEnabled && models.draft()?.notifyRate == false, "Turning the rate alert off disables its threshold")
        let remove = models.subviews.flatMap(\.subviews).compactMap { $0 as? NSButton }.first { $0.image?.accessibilityDescription == L("Parar de monitorar gemini-argon", "Stop monitoring gemini-argon") }!
        remove.performClick(nil)
        check(models.monitoredModels.isEmpty && models.frame.height == emptyHeight, "Removing the last model restores the empty list")
        let panel = PreferencesPanel(); panel.startupState = { .disabled }; panel.onModelChoices = { choices }
        var saved: AppPreferences?; panel.onSave = { saved = $0; return true }
        panel.present(AppPreferences()); panel.monitor("claude-opus")
        func all(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(all) }
        let content = panel.window!.contentView!
        let section = all(content).compactMap { $0 as? ModelAlertControls }.first!
        check(!section.isHidden && section.monitoredModels == ["claude-opus"], "A notification's Monitor action opens the alerts tab with the model listed")
        all(content).compactMap { $0 as? NSButton }.first { $0.title == L("Salvar", "Save") }!.performClick(nil)
        check(saved?.monitoredModels == [MonitoredModel(model: "claude-opus")], "Saving keeps the monitored model")
        panel.window?.orderOut(nil)
    }
    print("PASS: Cursor controls, numeric validation, pt-BR/en, fixed preferences footer and per-model alert settings")
}
