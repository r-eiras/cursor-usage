import AppKit

@MainActor final class PreferencesPanel: NSWindowController, NSWindowDelegate {
    var onSave: ((AppPreferences) -> Bool)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var canDisconnect: (() -> Bool)?
    var onAbout: (() -> Void)?
    var onReportIssue: (() -> Void)?
    private var updateButton: NSButton?
    var onCheckUpdates: (() -> Void)?
    var onPreview: ((AppPreferences) -> String)?
    var onPreviewUsage: ((AppPreferences) -> Double?)?
    var onPreviewParts: ((AppPreferences) -> [MenuBarPresentation.Part])?
    var onCursorAssessment: ((AppPreferences) -> BudgetAssessment?)?
    var startupState: (() -> LoginItemState)?
    var onStartupChange: ((Bool) throws -> Void)?
    var onStartupSettings: (() -> Void)?
    var onModelChoices: (() -> [ModelAlertControls.Choice])?
    var onModelPaces: (() -> [String: Int64])?
    private let mode = NSPopUpButton(), basis = NSPopUpButton()
    private let iconStyle = NSPopUpButton(), iconColor = NSPopUpButton(), opening = NSPopUpButton(), density = NSPopUpButton(), sync = NSPopUpButton(), language = NSPopUpButton()
    // One sample per color level, so the thresholds are visible next to the choice.
    private let iconLegend: [(usage: Double, image: NSImageView, label: NSTextField)] = [(0.1, "< 30%"), (0.45, "30–60%"), (0.75, "60–90%"), (0.95, "≥ 90%")].map { ($0.0, NSImageView(), NSTextField(labelWithString: $0.1)) }
    private let iconColorNote = NSTextField(wrappingLabelWithString: "")
    private let colorNumbers = NSButton(checkboxWithTitle: L("Números também, cada um pelo seu período", "Numbers too, each by its own period"), target: nil, action: nil)
    private let showIcon = NSButton(checkboxWithTitle: L("Mostrar ícone", "Show icon"), target: nil, action: nil)
    private let showDetailedLabels = NSButton(checkboxWithTitle: L("Mostrar rótulos Hoje e Ciclo", "Show Today and Cycle labels"), target: nil, action: nil)
    private let startup = NSButton(checkboxWithTitle: L("Iniciar ao entrar no Mac", "Open at login"), target: nil, action: nil)
    private let startupDescription = NSTextField(wrappingLabelWithString: "")
    private let preview = NSButton(), status = NSTextField(wrappingLabelWithString: ""), previewExplanation = NSTextField(wrappingLabelWithString: "")
    private let disconnect = NSButton(image: NSImage(systemSymbolName: "rectangle.portrait.and.arrow.right", accessibilityDescription: nil)!, target: nil, action: nil)
    private let tabs = NSSegmentedControl(labels: [L("Barra", "Menu bar"), L("Avisos", "Alerts"), L("App", "App")], trackingMode: .selectOne, target: nil, action: nil)
    private let alerts = CursorAlertControls()
    private let models = ModelAlertControls()
    private var alertsSection: NSView?
    private let notificationSettings = NSButton(title: L("Ajustar notificações no macOS…", "Notification settings in macOS…"), target: nil, action: nil)
    private let scroll = OverlayScrollView()
    private var sections: [NSView] = []
    private var original = AppPreferences()
    private var suspendedForMenuBar = false
    private static let footer: CGFloat = 56
    init() {
        let height = Self.fittedHeight()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: height), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = L("Configurações — Cursor Usage", "Settings — Cursor Usage"); window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua); window.backgroundColor = NSColor(srgbRed: 0.04, green: 0.055, blue: 0.07, alpha: 1)
        window.contentMinSize = NSSize(width: 520, height: 360); window.contentMaxSize = NSSize(width: 520, height: 760)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: height)); window.contentView = container
        scroll.frame = NSRect(x: 0, y: Self.footer, width: 520, height: height - Self.footer)
        scroll.autoresizingMask = [.width, .height]; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.drawsBackground = false
        scroll.fadeColor = window.backgroundColor; scroll.keepsScrollerVisible = true
        let content = SettingsContent(frame: NSRect(x: 0, y: 0, width: 520, height: 600)); scroll.documentView = content; container.addSubview(scroll)
        super.init(window: window); window.delegate = self
        func label(_ text: String, in parent: NSView, x: CGFloat, y: CGFloat, width: CGFloat, size: CGFloat = 12, muted: Bool = false) {
            let field = NSTextField(labelWithString: text); field.frame = NSRect(x: x, y: y, width: width, height: 24)
            field.font = .systemFont(ofSize: size, weight: size >= 14 ? .semibold : .regular); field.textColor = muted ? .secondaryLabelColor : .labelColor; parent.addSubview(field)
        }
        let logo = NSImageView(frame: NSRect(x: 22, y: 23, width: 30, height: 34)); logo.image = CursorMark.appImage(size: 32, template: false); content.addSubview(logo)
        label("Cursor Usage", in: content, x: 64, y: 28, width: 220, size: 20)
        let account = NSButton(title: L("Conta do Cursor", "Cursor account"), target: self, action: #selector(openAccount))
        account.frame = NSRect(x: 302, y: 24, width: 140, height: 28); account.bezelStyle = .rounded; account.font = .systemFont(ofSize: 11)
        account.toolTip = L("Abrir o painel oficial sem salvar as alterações desta janela.", "Open the official dashboard without saving this window's changes."); content.addSubview(account)
        disconnect.frame = NSRect(x: 454, y: 24, width: 30, height: 28); disconnect.isBordered = false; disconnect.target = self; disconnect.action = #selector(disconnectAccount)
        disconnect.toolTip = L("Desconectar conta neste app", "Disconnect this app's account"); disconnect.setAccessibilityLabel(L("Desconectar conta", "Disconnect account")); disconnect.identifier = NSUserInterfaceItemIdentifier("disconnectAccount"); content.addSubview(disconnect)
        tabs.frame = NSRect(x: 22, y: 88, width: 476, height: 28); tabs.selectedSegment = 0; tabs.segmentStyle = .rounded; tabs.font = .systemFont(ofSize: 12, weight: .medium)
        tabs.target = self; tabs.action = #selector(selectTab); content.addSubview(tabs)
        personalNote.frame = NSRect(x: 22, y: 119, width: 476, height: 16); personalNote.font = .systemFont(ofSize: 11); personalNote.textColor = .secondaryLabelColor; personalNote.lineBreakMode = .byTruncatingTail
        personalNote.isHidden = true; content.addSubview(personalNote)
        for popup in [density, iconColor] { popup.autoenablesItems = false }
        let bar = SettingsSurface(frame: NSRect(x: 18, y: 140, width: 484, height: 520))
        let alertsSection = SettingsSurface(frame: NSRect(x: 18, y: 140, width: 484, height: 482)); self.alertsSection = alertsSection
        let app = SettingsSurface(frame: NSRect(x: 18, y: 140, width: 484, height: 380))
        sections = [bar, alertsSection, app]; for section in sections { content.addSubview(section) }
        SettingsStyle.header(L("Na barra de menus", "In the menu bar"), in: bar, y: 14)
        mode.addItems(withTitles: MenuDisplayMode.allCases.map(\.title)); basis.addItems(withTitles: UsageDisplayBasis.allCases.map(\.title))
        density.addItems(withTitles: MenuBarDensity.allCases.map(\.title)); opening.addItems(withTitles: MenuOpenBehavior.allCases.map(\.title))
        iconStyle.addItems(withTitles: MenuIconStyle.allCases.map(\.title)); iconColor.addItems(withTitles: IconColorBasis.allCases.map(\.title))
        for (index, style) in MenuIconStyle.allCases.enumerated() { iconStyle.item(at: index)?.image = style == .app ? CursorMark.appImage() : CursorMark.image() }
        sync.addItems(withTitles: SyncInterval.allCases.map(\.title)); language.addItems(withTitles: AppLanguage.allCases.map(\.title))
        for (title, control, y, parent) in [(L("Formato", "Format"), mode, CGFloat(50), bar), (L("Exibir valores", "Show values"), basis, CGFloat(86), bar), (L("Espaço na barra", "Menu bar space"), density, CGFloat(122), bar), (L("Abrir cartão", "Open card"), opening, CGFloat(158), bar), (L("Ícone da barra", "Menu bar icon"), iconStyle, CGFloat(194), bar), (L("Cores pelo uso", "Colors by usage"), iconColor, CGFloat(230), bar), (L("Sincronizar a cada", "Sync every"), sync, CGFloat(50), app), (L("Idioma", "Language"), language, CGFloat(86), app)] {
            label(title, in: parent, x: 16, y: y + 3, width: 170, size: 12, muted: true)
            control.frame = NSRect(x: 188, y: y, width: 280, height: 26); control.font = .systemFont(ofSize: 12); control.target = self; control.action = #selector(changed); parent.addSubview(control)
        }
        for (index, sample) in iconLegend.enumerated() {
            let x = 188 + CGFloat(index) * 70
            sample.image.frame = NSRect(x: x, y: 290, width: 14, height: 14); sample.image.imageScaling = .scaleProportionallyUpOrDown; bar.addSubview(sample.image)
            sample.label.frame = NSRect(x: x + 18, y: 289, width: 52, height: 16); sample.label.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular); sample.label.textColor = .secondaryLabelColor; bar.addSubview(sample.label)
        }
        iconColorNote.frame = NSRect(x: 188, y: 310, width: 280, height: 42); iconColorNote.font = .systemFont(ofSize: 10); iconColorNote.textColor = .secondaryLabelColor; bar.addSubview(iconColorNote)
        colorNumbers.frame = NSRect(x: 188, y: 262, width: 280, height: 22)
        showIcon.frame = NSRect(x: 16, y: 354, width: 158, height: 22); showDetailedLabels.frame = NSRect(x: 188, y: 354, width: 280, height: 22)
        showDetailedLabels.toolTip = L("Oculta só os nomes; os valores continuam na ordem hoje e ciclo.", "Hides only the labels; values remain in today then cycle order.")
        for control in [showIcon, showDetailedLabels, colorNumbers] { control.font = .systemFont(ofSize: 12); control.target = self; control.action = #selector(changed); bar.addSubview(control) }
        SettingsStyle.separator(in: bar, y: 388)
        SettingsStyle.header(L("Prévia da barra", "Menu bar preview"), in: bar, y: 402)
        let capsule = SettingsSurface(frame: NSRect(x: 16, y: 430, width: 452, height: 48), accent: true); bar.addSubview(capsule)
        preview.frame = NSRect(x: 14, y: 8, width: 424, height: 32); preview.isBordered = false; preview.alignment = .left; preview.focusRingType = .none
        preview.identifier = NSUserInterfaceItemIdentifier("menuBarPreview"); preview.setAccessibilityRole(.staticText); preview.setAccessibilityLabel(L("Prévia da barra de menus", "Menu bar preview")); capsule.addSubview(preview)
        previewExplanation.frame = NSRect(x: 16, y: 486, width: 452, height: 30); previewExplanation.font = .systemFont(ofSize: 11); previewExplanation.textColor = .secondaryLabelColor; bar.addSubview(previewExplanation)
        alerts.frame.origin = NSPoint(x: SettingsStyle.inset, y: 16); alerts.onChange = { [weak self] in self?.changed() }; alertsSection.addSubview(alerts)
        models.onChange = { [weak self] in self?.changed() }; models.onResize = { [weak self] in self?.relayoutAlerts() }; alertsSection.addSubview(models)
        notificationSettings.bezelStyle = .rounded; notificationSettings.font = .systemFont(ofSize: 12); notificationSettings.target = self; notificationSettings.action = #selector(openNotificationSettings); alertsSection.addSubview(notificationSettings)
        status.frame = NSRect(x: SettingsStyle.inset, y: 438, width: 452, height: 34); status.font = .systemFont(ofSize: 11); status.textColor = .secondaryLabelColor; alertsSection.addSubview(status)
        SettingsStyle.header(L("Conexão", "Connection"), in: app, y: 14)
        SettingsStyle.separator(in: app, y: 126)
        SettingsStyle.header(L("Início automático", "Open at login"), in: app, y: 140)
        startup.frame = NSRect(x: 16, y: 168, width: 400, height: 22); startup.font = .systemFont(ofSize: 12); startup.toolTip = L("Aplicado imediatamente; não depende de Salvar.", "Applied immediately; does not depend on Save."); startup.target = self; startup.action = #selector(startupChanged); app.addSubview(startup)
        let settings = NSButton(image: NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: L("Abrir Itens de Início", "Open Login Items"))!, target: self, action: #selector(openStartupSettings)); settings.frame = NSRect(x: 434, y: 167, width: 30, height: 24); settings.isBordered = false; app.addSubview(settings)
        startupDescription.frame = NSRect(x: 16, y: 194, width: 452, height: 34); startupDescription.font = .systemFont(ofSize: 11); startupDescription.textColor = .secondaryLabelColor; app.addSubview(startupDescription)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L("Desenvolvimento", "Development")
        SettingsStyle.separator(in: app, y: 238)
        SettingsStyle.header(L("Versão e suporte", "Version and support"), in: app, y: 252)
        label("Cursor Usage \(version)", in: app, x: 16, y: 274, width: 450, size: 11, muted: true)
        for (title, x, action) in [(L("Sobre", "About"), CGFloat(16), #selector(aboutAction)), (L("Verificar atualizações…", "Check for Updates…"), CGFloat(162), #selector(updateAction))] {
            let button = NSButton(title: title, target: self, action: action); button.frame = NSRect(x: x, y: 302, width: x == 16 ? 130 : 302, height: 28); button.bezelStyle = .rounded; button.font = .systemFont(ofSize: 12); app.addSubview(button)
            if action == #selector(updateAction) { updateButton = button }
        }
        let report = NSButton(title: L("Reportar problema…", "Report an issue…"), target: self, action: #selector(reportIssue))
        report.frame = NSRect(x: 16, y: 338, width: 448, height: 28); report.bezelStyle = .rounded; report.font = .systemFont(ofSize: 12); app.addSubview(report)
        for (title, x, action) in [(L("Cancelar", "Cancel"), CGFloat(290), #selector(cancel)), (L("Salvar", "Save"), CGFloat(398), #selector(save))] {
            let button = NSButton(title: title, target: self, action: action); button.frame = NSRect(x: x, y: 12, width: 100, height: 30); button.bezelStyle = .rounded
            if action == #selector(save) { button.keyEquivalent = "\r"; button.bezelColor = NSColor(srgbRed: 0.42, green: 0.87, blue: 0.73, alpha: 1) }; container.addSubview(button)
        }
        relayoutAlerts(); selectTab()
    }
    required init?(coder: NSCoder) { fatalError() }
    // The per-model list grows with each monitored model; the alerts tab and its scroll height follow it.
    private func relayoutAlerts() {
        guard let section = alertsSection else { return }
        models.frame.origin = NSPoint(x: SettingsStyle.inset, y: alerts.frame.maxY + 16)
        status.frame = NSRect(x: SettingsStyle.inset, y: models.frame.maxY + 8, width: 452, height: 34)
        notificationSettings.sizeToFit(); notificationSettings.frame = NSRect(x: SettingsStyle.inset, y: status.frame.maxY + 4, width: notificationSettings.frame.width + 16, height: 28)
        section.frame.size.height = notificationSettings.frame.maxY + 14
        if tabs.selectedSegment == 1, let document = scroll.documentView { document.frame.size.height = 140 + section.frame.height + 20 }
    }
    // Opens the alerts tab with a model already on the monitored list, ready for its limits.
    func monitor(_ model: String) { tabs.selectedSegment = 1; selectTab(); models.updateSpend(onModelChoices?() ?? []); models.setPaces(onModelPaces?() ?? [:]); models.monitor(model) }
    static func fittedHeight(screen: NSScreen? = NSScreen.main) -> CGFloat { min(640, ((screen?.visibleFrame.height ?? 800) * 0.8).rounded(.down)) }
    // Shown under the tabs for a personal plan, whose options that need dollars or daily figures are greyed out.
    private let personalNote = NSTextField(labelWithString: "")
    private var personalPlan: String?? = nil
    var isPersonalAccount: Bool { personalPlan != nil }
    // `bringToFront` is false when an open window only follows a change of account behind the user's back.
    func present(_ value: AppPreferences, providerLimitMicros: Int64? = nil, personalPlan: String?? = nil, bringToFront: Bool = true) {
        self.personalPlan = personalPlan
        suspendedForMenuBar = false
        original = value
        disconnect.isEnabled = canDisconnect?() ?? false
        mode.selectItem(at: MenuDisplayMode.allCases.firstIndex(of: value.menuMode)!)
        basis.selectItem(at: UsageDisplayBasis.allCases.firstIndex(of: value.cursorUsageBasis)!)
        iconStyle.selectItem(at: MenuIconStyle.allCases.firstIndex(of: value.menuIconStyle)!); iconColor.selectItem(at: IconColorBasis.allCases.firstIndex(of: value.iconColorBasis)!); opening.selectItem(at: MenuOpenBehavior.allCases.firstIndex(of: value.menuOpenBehavior)!); density.selectItem(at: MenuBarDensity.allCases.firstIndex(of: value.menuBarDensity)!); sync.selectItem(at: SyncInterval.allCases.firstIndex(of: value.syncInterval)!)
        language.selectItem(at: AppLanguage.allCases.firstIndex(of: value.language)!); showIcon.state = value.showIcon ? .on : .off; showDetailedLabels.state = value.showDetailedLabels ? .on : .off; colorNumbers.state = value.colorNumbers ? .on : .off
        var alert = QuotaAlertDraft(); alert.personalEnabled = value.personalBudgetEnabled; alert.personalLimit = Double(value.personalBudgetMicros) / 1_000_000
        alert.cycleEnabled = value.notifyCycle; alert.cyclePercent = value.alertPercent; alert.dailyEnabled = value.notifyDaily
        alert.dailyPercent = value.dailyAlertPercent; alert.sound = value.alertSound; alert.renewal = value.notifyRenewal
        alerts.present(alert, officialLimit: providerLimitMicros.map { Double($0) / 1_000_000 })
        alerts.personalAccount = isPersonalAccount
        if isPersonalAccount {
            density.selectItem(at: MenuBarDensity.allCases.firstIndex(of: Self.personalFallback(value.menuBarDensity))!)
            if value.iconColorBasis == .day { iconColor.selectItem(at: IconColorBasis.allCases.firstIndex(of: .cycle)!) }
        }
        personalNote.isHidden = !isPersonalAccount
        // One short line fits between the tabs and the sections; the tooltip says the rest.
        personalNote.stringValue = L("Plano pessoal: opções em cinza são de contas corporativas.", "Personal plan: greyed-out options are for corporate accounts.")
        personalNote.toolTip = L("Contas pessoais mostram só a porcentagem da cota incluída, sem valores em dólar nem cota diária.",
                                 "Personal accounts show only the share of the included usage, with no dollar amounts and no daily allowance.")
        models.present(ModelAlertControls.Draft(notifyNewModel: value.notifyNewModel, notifyRate: value.notifyModelRate, ratePercent: value.modelRatePercent, monitored: value.monitoredModels,
                                               rateUnit: value.modelRateUnit, rateAmountMicros: value.modelRateAmountMicros, rateReference: value.modelRateReference), choices: onModelChoices?() ?? [])
        models.setPaces(onModelPaces?() ?? [:]); models.personalAccount = isPersonalAccount
        refreshStartup(); changed(); window?.setContentSize(NSSize(width: 520, height: Self.fittedHeight()))
        selectTab(); guard bringToFront else { return }
        if window?.isVisible != true { window?.center() }; showWindow(nil); setDocked(true); Self.activateApp()
    }
    // While Settings is open the app is a regular one, in the Dock and in Cmd+Tab, so switching apps never loses the
    // window; closing it returns the app to the menu bar only.
    private func setDocked(_ docked: Bool) { Self.applyActivationPolicy(docked ? .regular : .accessory) }
    // Tests swap these to check the Dock behaviour without putting the test process in the Dock or taking focus.
    static var applyActivationPolicy: (NSApplication.ActivationPolicy) -> Void = { if NSApp.activationPolicy() != $0 { NSApp.setActivationPolicy($0) } }
    static var activateApp: () -> Void = { NSApp.activate(ignoringOtherApps: true) }
    func suspendForMenuBar() {
        guard window?.isVisible == true else { return }
        suspendedForMenuBar = true; window?.orderOut(nil)
    }
    func resumeIfSuspended() -> Bool {
        guard suspendedForMenuBar else { return false }
        suspendedForMenuBar = false; showWindow(nil); setDocked(true); Self.activateApp()
        return true
    }
    func windowWillClose(_ notification: Notification) { suspendedForMenuBar = false; setDocked(false) }
    private func menuDraft() -> AppPreferences {
        var value = original
        value.menuMode = MenuDisplayMode.allCases[mode.indexOfSelectedItem]
        value.menuIconStyle = MenuIconStyle.allCases[iconStyle.indexOfSelectedItem]; value.iconColorBasis = IconColorBasis.allCases[iconColor.indexOfSelectedItem]
        value.cursorUsageBasis = UsageDisplayBasis.allCases[basis.indexOfSelectedItem]
        value.menuOpenBehavior = MenuOpenBehavior.allCases[opening.indexOfSelectedItem]
        value.menuBarDensity = MenuBarDensity.allCases[density.indexOfSelectedItem]
        value.syncInterval = SyncInterval.allCases[sync.indexOfSelectedItem]; value.language = AppLanguage.allCases[language.indexOfSelectedItem]
        value.showIcon = showIcon.state == .on; value.showDetailedLabels = showDetailedLabels.state == .on; value.colorNumbers = colorNumbers.state == .on
        // A personal account shows the closest choice it can use; the corporate one saved before is kept underneath.
        if isPersonalAccount {
            if Self.personalFallback(original.menuBarDensity) == value.menuBarDensity { value.menuBarDensity = original.menuBarDensity }
            if original.iconColorBasis == .day && value.iconColorBasis == .cycle { value.iconColorBasis = .day }
        }
        return value
    }
    static func personalFallback(_ density: MenuBarDensity) -> MenuBarDensity { density == .detailed || density == .compactToday ? .compact : density }
    private func draft() -> AppPreferences? {
        guard let alert = alerts.draft(), let modelAlerts = models.draft() else { return nil }
        var value = menuDraft()
        value.personalBudgetEnabled = alert.personalEnabled; if alert.personalEnabled { value.personalBudgetMicros = Int64((alert.personalLimit * 1_000_000).rounded()) }
        value.notifyCycle = alert.cycleEnabled; value.alertPercent = alert.cyclePercent; value.notifyDaily = alert.dailyEnabled; value.dailyAlertPercent = alert.dailyPercent
        value.notifyNewModel = modelAlerts.notifyNewModel; value.notifyModelRate = modelAlerts.notifyRate; value.modelRatePercent = modelAlerts.ratePercent; value.monitoredModels = modelAlerts.monitored
        value.modelRateUnit = modelAlerts.rateUnit; value.modelRateAmountMicros = modelAlerts.rateAmountMicros; value.modelRateReference = modelAlerts.rateReference
        value.alertSound = alert.sound; value.notifyRenewal = alert.renewal; return value
    }
    @objc private func openAccount() { suspendForMenuBar(); onConnect?() }
    @objc private func disconnectAccount() { onDisconnect?(); disconnect.isEnabled = canDisconnect?() ?? false }
    @objc private func aboutAction() { onAbout?() }
    @objc private func reportIssue() { onReportIssue?() }
    func setUpdateChecking(_ checking: Bool, installing: Bool = false) {
        updateButton?.isEnabled = !checking
        updateButton?.title = installing ? L("Atualizando…", "Updating…") : checking ? L("Verificando…", "Checking…") : L("Verificar atualizações…", "Check for Updates…")
    }
    @objc private func updateAction() { onCheckUpdates?() }
    @objc private func selectTab() {
        let index = max(0, tabs.selectedSegment)
        for (position, section) in sections.enumerated() { section.isHidden = position != index }
        if let document = scroll.documentView { document.frame.size.height = 140 + sections[index].frame.height + 20; document.scroll(.zero) }
    }
    @objc private func changed() {
        let layout = MenuBarDensity.allCases[max(0, density.indexOfSelectedItem)], showsText = layout.showsText
        showIcon.isEnabled = showsText; showDetailedLabels.isEnabled = layout == .detailed; colorNumbers.isEnabled = showsText
        for control in [mode, basis] { control.isEnabled = showsText }
        let value = draft() ?? menuDraft()
        // A personal account has no dollars and no daily figures: those choices stay visible but cannot be picked.
        let personal = isPersonalAccount
        if personal { mode.isEnabled = false }
        for index in [MenuBarDensity.allCases.firstIndex(of: .detailed)!, MenuBarDensity.allCases.firstIndex(of: .compactToday)!] { density.item(at: index)?.isEnabled = !personal }
        iconColor.item(at: IconColorBasis.allCases.firstIndex(of: .day)!)?.isEnabled = !personal
        iconStyle.isEnabled = value.showIcon || value.menuBarDensity == .iconsOnly; iconColor.isEnabled = iconStyle.isEnabled
        let colored = (iconColor.isEnabled && value.iconColorBasis != .off) || (colorNumbers.isEnabled && value.colorNumbers)
        for sample in iconLegend { sample.image.image = CursorMark.icon(style: value.menuIconStyle, usage: sample.usage); sample.image.alphaValue = colored ? 1 : 0.35; sample.label.alphaValue = colored ? 1 : 0.5 }
        let note: String = switch value.iconColorBasis {
        case .off: L("O ícone fica sempre na cor da barra.", "The icon always keeps the menu bar's color.")
        case .cycle: L("Consumido no ciclo, sobre a cota do Cursor ou sua meta pessoal. Muda devagar ao longo do mês.", "Used this cycle, against Cursor's allowance or your personal goal. Changes slowly over the month.")
        case .day: L("Gasto de hoje, sobre a cota do dia: o que sobrava no ciclo dividido pelos dias até a renovação. Zera à meia-noite.", "Spent today, against today's allowance: what was left in the cycle divided by the days to renewal. Resets at midnight.")
        }
        let numbers = !(colorNumbers.isEnabled && value.colorNumbers) ? "" : personal ? L(" Números: pela cota incluída.", " Numbers: by the included usage.")
            : L(" Números: hoje pela cota do dia, ciclo pela do ciclo.", " Numbers: today by the daily allowance, cycle by the cycle's.")
        iconColorNote.stringValue = (iconColor.isEnabled ? note : L("Ícone oculto.", "Icon hidden.")) + numbers
        CursorMark.configure(preview, title: onPreview?(value) ?? "—", showsIcon: value.showIcon || value.menuBarDensity == .iconsOnly, style: value.menuIconStyle, usage: onPreviewUsage?(value) ?? nil,
                            parts: value.colorNumbers ? onPreviewParts?(value) : nil)
        previewExplanation.stringValue = value.menuBarDensity == .detailed ? L("Hoje → ciclo. A cota diária é calculada pelo app.", "Today → cycle. The daily allowance is calculated by the app.") : value.menuBarDensity == .compact ? L("Só a cota do ciclo, no formato escolhido.", "Only the cycle quota, in your chosen format.") : value.menuBarDensity == .compactToday ? L("Só o dia, sobre a cota diária calculada pelo app.", "Only today, against the daily allowance the app calculates.") : L("Só o ícone; abra o cartão para ver os valores.", "Only the icon; open the card to see values.")
        refreshAssessment(value)
    }

    private func refreshAssessment(_ value: AppPreferences) {
        let assessment = onCursorAssessment?(value)
        alerts.setAssessment(allowance: assessment?.dailyLimitMicros.map { $0 / 1_000_000 }, todayUsed: assessment?.todaySpentMicros.map { Double($0) / 1_000_000 }, observedSince: nil)
    }
    func updateReadings() { if window?.isVisible == true { changed(); models.updateSpend(onModelChoices?() ?? []); models.setPaces(onModelPaces?() ?? [:]) } }
    func setStatus(_ value: String) { status.stringValue = value }
    func windowDidBecomeKey(_ notification: Notification) { refreshStartup() }
    private func refreshStartup() { let state = startupState?() ?? .unavailable; startup.state = state == .requiresApproval ? .mixed : (state == .enabled ? .on : .off); startupDescription.stringValue = state.message }
    @objc private func startupChanged() { do { try onStartupChange?(startup.state != .off); refreshStartup() } catch { refreshStartup(); startupDescription.stringValue = LoginItemManager.failureMessage(error, state: startupState?() ?? .unavailable) } }
    @objc private func openStartupSettings() { onStartupSettings?() }
    @objc private func save() { guard let value = draft() else { tabs.selectedSegment = 1; selectTab(); setStatus(L("Informe uma meta válida, um aviso diário de 1% a 100%, um ritmo de modelo de 1% a 10.000% ou acima de US$ 0,01, e limites de modelo maiores que zero.", "Enter a valid goal, a daily alert from 1% to 100%, a model pace from 1% to 10,000% or above US$ 0.01, and model limits above zero.")); return }; guard onSave?(value) == true else { return }; suspendedForMenuBar = false; window?.orderOut(nil); setDocked(false) }
    @objc private func openNotificationSettings() { NSWorkspace.shared.open(NotificationAdvice.settingsURL) }
    @objc private func cancel() { suspendedForMenuBar = false; window?.orderOut(nil); setDocked(false) }
}
@MainActor private final class SettingsContent: NSView { override var isFlipped: Bool { true } }
@MainActor private final class SettingsSurface: NSView {
    private let accent: Bool
    init(frame: NSRect, accent: Bool = false) { self.accent = accent; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
        NSColor(srgbRed: accent ? 0.035 : 0.07, green: accent ? 0.065 : 0.09, blue: accent ? 0.075 : 0.11, alpha: 1).setFill(); path.fill()
        (accent ? NSColor(srgbRed: 0.42, green: 0.87, blue: 0.73, alpha: 0.24) : NSColor.white.withAlphaComponent(0.065)).setStroke(); path.lineWidth = 1; path.stroke()
    }
}
