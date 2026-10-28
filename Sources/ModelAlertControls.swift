import AppKit

// Per-model alerts in settings: a model's first use, spending above the costliest model, and goals for chosen models.
@MainActor final class ModelAlertControls: NSView, NSTextFieldDelegate {
    struct Draft: Equatable {
        var notifyNewModel = true; var notifyRate = true; var ratePercent = 50; var monitored: [MonitoredModel] = []
        var rateUnit = RateThresholdUnit.percent; var rateAmountMicros: Int64 = 1_000_000; var rateReference: String? = nil
    }
    struct Choice: Equatable { let model: String; let cycleSpendMicros: Int64; let isNew: Bool; var daySpendMicros: Int64 = 0 }
    var onChange: (() -> Void)?
    var onResize: (() -> Void)?
    private let newModel = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rate = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    // Threshold, its unit and the reference it is measured against: "[50] [%] above [your costliest model]".
    private let rateThreshold = NSTextField(), rateUnit = NSPopUpButton(), rateAbove = NSTextField(labelWithString: ""), rateReference = NSPopUpButton()
    private var ratePercent = 50, rateAmountMicros: Int64 = 1_000_000, savedReference: String?
    // Each model's usual 15-minute spend, current or saved, so the reference's pace and the trigger can be shown.
    private var paces: [String: Int64] = [:]
    private let paceInfo = NSTextField(wrappingLabelWithString: "")
    private let add = NSButton(title: "", target: nil, action: nil)
    private let empty = NSTextField(wrappingLabelWithString: "")
    private let footnote = NSTextField(wrappingLabelWithString: "")
    private var rows: [LimitRow] = []
    private var choices: [Choice] = []
    private static let listTop: CGFloat = 306, rowHeight: CGFloat = 30
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(x: SettingsStyle.inset, y: 0, width: 452, height: 300))
        SettingsStyle.separator(in: self, x: 0, y: 0)
        SettingsStyle.header(L("Avisos por modelo", "Per-model alerts"), in: self, x: 0, y: 14)
        newModel.title = L("Avisar quando um modelo for usado pela primeira vez", "Notify when a model is used for the first time")
        newModel.frame = NSRect(x: 0, y: 42, width: 452, height: 22)
        SettingsStyle.note(L("Pega o teste de um modelo novo logo na sincronização seguinte.", "Catches a new model being tried at the next sync."), in: self, x: 22, y: 66, width: 430)
        rate.frame = NSRect(x: 0, y: 94, width: 452, height: 22)
        rate.title = L("Avisar quando um modelo gastar muito acima da referência", "Notify when a model spends far above the reference")
        rateThreshold.frame = NSRect(x: 22, y: 121, width: 64, height: 24); rateThreshold.font = .systemFont(ofSize: 12); rateThreshold.alignment = .right; rateThreshold.delegate = self
        rateThreshold.setAccessibilityLabel(L("Quanto acima da referência", "How far above the reference"))
        rateUnit.frame = NSRect(x: 90, y: 120, width: 70, height: 26); rateUnit.addItems(withTitles: RateThresholdUnit.allCases.map(\.title))
        rateAbove.stringValue = L("acima de", "above"); rateAbove.frame = NSRect(x: 164, y: 125, width: 58, height: 16); rateAbove.font = .systemFont(ofSize: 12); rateAbove.textColor = .secondaryLabelColor
        rateReference.frame = NSRect(x: 222, y: 120, width: 230, height: 26)
        for popup in [rateUnit, rateReference] { popup.font = .systemFont(ofSize: 12); popup.target = self; popup.action = #selector(rateChanged) }
        SettingsStyle.note(L("Compara os últimos 15 minutos de cada modelo com os 15 minutos típicos da referência nos últimos 14 dias. Se a referência sair do histórico, vale o último ritmo guardado.", "Compares each model's last 15 minutes with the reference's usual 15 minutes over the past 14 days. If the reference leaves the history, its last saved pace is used."), in: self, x: 22, y: 182, width: 430, height: 46)
        // A line and some room keep the pace alert apart from the monitored models below it.
        SettingsStyle.separator(in: self, x: 0, y: 244)
        SettingsStyle.header(L("Modelos monitorados", "Monitored models"), in: self, x: 0, y: 260, size: 12)
        // Each amount sits beside its own limit, so the cycle total is not mistaken for today's spend.
        for (title, x, width, align) in [(L("Modelo", "Model"), CGFloat(0), CGFloat(142), NSTextAlignment.left), (L("Hoje", "Today"), 146, 58, .right),
                                         (L("Limite/dia", "Limit/day"), 210, 62, .left), (L("No ciclo", "This cycle"), 278, 62, .right),
                                         (L("Limite/ciclo", "Limit/cycle"), 344, 66, .left)] {
            let label = NSTextField(labelWithString: title); label.frame = NSRect(x: x, y: 286, width: width, height: 16)
            label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor; label.alignment = align; addSubview(label)
        }
        empty.stringValue = L("Nenhum modelo monitorado. Escolha um com o botão abaixo.", "No monitored models. Pick one with the button below.")
        empty.font = .systemFont(ofSize: 11); empty.textColor = .secondaryLabelColor
        add.title = L("Monitorar modelo…", "Monitor a model…"); add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading; add.bezelStyle = .rounded; add.font = .systemFont(ofSize: 12); add.target = self; add.action = #selector(showChoices)
        footnote.stringValue = L("Os limites são metas suas. A cota do Cursor é uma só para todos os modelos.", "Limits are your own goals. Cursor's allowance is shared by every model.")
        footnote.font = .systemFont(ofSize: 11); footnote.textColor = .secondaryLabelColor
        for control in [newModel, rate] { control.font = .systemFont(ofSize: 12); control.target = self; control.action = #selector(changed); addSubview(control) }
        paceInfo.frame = NSRect(x: 22, y: 150, width: 430, height: 30); paceInfo.font = .systemFont(ofSize: 11, weight: .medium); paceInfo.textColor = .labelColor
        for view in [rateThreshold, rateUnit, rateAbove, rateReference, paceInfo, empty, add, footnote] { addSubview(view) }
        relayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    func present(_ value: Draft, choices: [Choice]) {
        self.choices = choices
        newModel.state = value.notifyNewModel ? .on : .off; rate.state = value.notifyRate ? .on : .off; presentedRate = value.notifyRate
        ratePercent = value.ratePercent; rateAmountMicros = value.rateAmountMicros; savedReference = value.rateReference
        rateUnit.selectItem(at: RateThresholdUnit.allCases.firstIndex(of: value.rateUnit)!); showThreshold(); fillReferences()
        rows.forEach { $0.removeFromSuperview() }; rows = []
        value.monitored.forEach(append); relayout(); refresh()
    }
    func draft() -> Draft? {
        guard readThreshold() else { return nil }
        var value = Draft(notifyNewModel: newModel.state == .on, notifyRate: personalAccount ? presentedRate : rate.state == .on, ratePercent: ratePercent)
        value.rateUnit = selectedUnit; value.rateAmountMicros = rateAmountMicros; value.rateReference = selectedReference
        for row in rows {
            guard let limits = row.limits() else { return nil }
            value.monitored.append(MonitoredModel(model: row.model, dailyLimitMicros: limits.daily, cycleLimitMicros: limits.cycle))
        }
        return value
    }
    // Adds a model to the list, or leaves it where it is when it is already monitored.
    func monitor(_ model: String) {
        guard !rows.contains(where: { $0.model == model }) else { return }
        append(MonitoredModel(model: model)); relayout(); onChange?()
    }
    var monitoredModels: [String] { rows.map(\.model) }
    // Keeps "This cycle" in step with each sync while settings stays open; limits being typed are left alone.
    func updateSpend(_ choices: [Choice]) {
        self.choices = choices; fillReferences()
        for row in rows { row.setSpend(choices.first { $0.model == row.model }) }
    }

    private func append(_ value: MonitoredModel) {
        let row = LimitRow(value, spend: choices.first { $0.model == value.model }, frame: NSRect(x: 0, y: 0, width: 452, height: Self.rowHeight))
        row.onChange = { [weak self] in self?.onChange?() }
        row.onRemove = { [weak self] row in self?.rows.removeAll { $0 === row }; row.removeFromSuperview(); self?.relayout(); self?.onChange?() }
        row.setEnabled(!personalAccount); rows.append(row); addSubview(row)
    }
    private func relayout() {
        for (index, row) in rows.enumerated() { row.frame.origin = NSPoint(x: 0, y: Self.listTop + CGFloat(index) * Self.rowHeight) }
        empty.isHidden = !rows.isEmpty; empty.frame = NSRect(x: 0, y: Self.listTop + 2, width: 452, height: 16)
        let listBottom = Self.listTop + max(CGFloat(rows.count) * Self.rowHeight, 24)
        add.sizeToFit(); add.frame = NSRect(x: 0, y: listBottom + 6, width: add.frame.width + 12, height: 26)
        footnote.frame = NSRect(x: 0, y: add.frame.maxY + 10, width: 452, height: 16)
        let height = footnote.frame.maxY + 4
        if frame.height != height { frame.size.height = height; onResize?() }
    }
    // A personal account reports no dollar cost per request, so the pace alert and dollar limits are not offered.
    var personalAccount = false { didSet { rate.state = personalAccount ? .off : (presentedRate ? .on : .off); refresh(); rows.forEach { $0.setEnabled(!personalAccount) } } }
    private var presentedRate = true
    private func refresh() {
        rate.isEnabled = !personalAccount; add.isEnabled = !personalAccount
        for control in [rateThreshold, rateUnit, rateReference] as [NSControl] { control.isEnabled = !personalAccount && rate.state == .on }
        rateAbove.alphaValue = rate.state == .on ? 1 : 0.5; paceInfo.alphaValue = rate.state == .on ? 1 : 0.5
        showPace()
    }
    func setPaces(_ value: [String: Int64]) { paces = value; showPace() }
    // "claude-opus usually spends US$ 10.00 in 15 min. Alerts when a model passes US$ 15.00 in 15 min."
    private func showPace() {
        let money = { (micros: Int64) in MenuBarPresentation.money(Double(micros)) }
        let name = selectedReference ?? paces.max { $0.value == $1.value ? $0.key > $1.key : $0.value < $1.value }?.key
        guard let name, let pace = paces[name], pace > 0 else {
            paceInfo.stringValue = selectedReference.map { L("Ainda sem ritmo de \($0): ele precisa ter sido usado em pelo menos 4 janelas de 15 min nos últimos 14 dias.", "No pace for \($0) yet: it needs use in at least four 15-minute windows over the past 14 days.") }
                ?? L("Ainda sem ritmo para comparar: um modelo precisa ter sido usado em pelo menos 4 janelas de 15 min nos últimos 14 dias.", "No pace to compare with yet: a model needs use in at least four 15-minute windows over the past 14 days.")
            return
        }
        _ = readThreshold()
        let trigger = selectedUnit == .percent ? Int64((Double(pace) * (1 + Double(ratePercent) / 100)).rounded(.up)) : pace + rateAmountMicros
        paceInfo.stringValue = L("\(name) costuma gastar \(money(pace)) em 15 min. Avisa quando um modelo passar de \(money(trigger)) em 15 min.",
                                 "\(name) usually spends \(money(pace)) in 15 min. Alerts when a model passes \(money(trigger)) in 15 min.")
    }
    @objc private func changed() { refresh(); onChange?() }
    private var selectedUnit: RateThresholdUnit { RateThresholdUnit.allCases[max(0, rateUnit.indexOfSelectedItem)] }
    private var selectedReference: String? { rateReference.selectedItem?.representedObject as? String }
    // The field shows the value of the selected unit; each unit keeps its own value while the other is shown.
    private func showThreshold() {
        rateThreshold.stringValue = selectedUnit == .percent ? "\(ratePercent)" : localizedDecimal(String(format: "%.2f", Double(rateAmountMicros) / 1_000_000))
        rateThreshold.placeholderString = selectedUnit == .percent ? "50" : localizedDecimal("1.00")
    }
    private func readThreshold() -> Bool {
        let text = rateThreshold.stringValue.trimmingCharacters(in: .whitespaces)
        if selectedUnit == .percent {
            guard let percent = Int(text), percent >= 1, percent <= 10_000 else { return false }
            ratePercent = percent
        } else {
            guard let amount = SettingsStyle.dollars(text), amount >= 0.01, amount < 100_000 else { return false }
            rateAmountMicros = Int64((amount * 1_000_000).rounded())
        }
        return true
    }
    // The costliest model, then the models used this cycle; a saved reference stays listed after it leaves the history.
    private func fillReferences() {
        let selected = rateReference.numberOfItems > 0 ? selectedReference : savedReference
        rateReference.removeAllItems()
        rateReference.addItem(withTitle: L("Seu modelo mais caro", "Your costliest model"))
        var models = choices.filter { $0.cycleSpendMicros > 0 }.map(\.model)
        if let selected, !models.contains(selected) { models.append(selected) }
        for model in models {
            rateReference.addItem(withTitle: model); rateReference.lastItem?.representedObject = model
        }
        if let selected, let index = models.firstIndex(of: selected) { rateReference.selectItem(at: index + 1) } else { rateReference.selectItem(at: 0) }
    }
    @objc private func rateChanged(_ sender: NSPopUpButton) {
        if sender === rateUnit { showThreshold() }
        showPace(); onChange?()
    }
    func controlTextDidChange(_ notification: Notification) { if (notification.object as? NSTextField) === rateThreshold { _ = readThreshold(); showPace(); onChange?() } }
    @objc private func showChoices() {
        let menu = NSMenu(); menu.autoenablesItems = false
        let available = choices.filter { choice in !rows.contains { $0.model == choice.model } }
        for choice in available {
            let title = "\(choice.model)  ·  \(MenuBarPresentation.money(Double(choice.cycleSpendMicros)))" + (choice.isNew ? L("  ·  novo", "  ·  new") : "")
            let item = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: ""); item.target = self; item.representedObject = choice.model; menu.addItem(item)
        }
        if available.isEmpty {
            let item = NSMenuItem(title: choices.isEmpty ? L("Sincronize para ver os modelos usados", "Sync to see the models in use") : L("Todos os modelos já estão na lista", "Every model is already listed"), action: nil, keyEquivalent: "")
            item.isEnabled = false; menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: add.bounds.height + 4), in: add)
    }
    @objc private func pick(_ item: NSMenuItem) { if let model = item.representedObject as? String { monitor(model) } }
}

@MainActor private final class LimitRow: NSView, NSTextFieldDelegate {
    let model: String
    var onChange: (() -> Void)?; var onRemove: ((LimitRow) -> Void)?
    private let daily = NSTextField(), cycle = NSTextField(), daySpent = NSTextField(labelWithString: ""), cycleSpent = NSTextField(labelWithString: "")
    override var isFlipped: Bool { true }
    init(_ value: MonitoredModel, spend: ModelAlertControls.Choice?, frame: NSRect) {
        model = value.model; super.init(frame: frame)
        let name = NSTextField(labelWithString: value.model); name.frame = NSRect(x: 0, y: 6, width: 142, height: 18)
        name.font = .monospacedSystemFont(ofSize: 11, weight: .regular); name.lineBreakMode = .byTruncatingMiddle; name.toolTip = value.model; addSubview(name)
        for (label, x) in [(daySpent, CGFloat(146)), (cycleSpent, 278)] {
            label.frame = NSRect(x: x, y: 6, width: label === daySpent ? 58 : 62, height: 18)
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); label.textColor = .secondaryLabelColor; label.alignment = .right; addSubview(label)
        }
        setSpend(spend)
        for (field, x, micros) in [(daily, CGFloat(210), value.dailyLimitMicros), (cycle, 344, value.cycleLimitMicros)] {
            field.frame = NSRect(x: x, y: 3, width: field === daily ? 62 : 66, height: 24); field.font = .systemFont(ofSize: 11); field.placeholderString = "—"; field.delegate = self
            field.stringValue = micros.map { localizedDecimal(String(format: "%.2f", Double($0) / 1_000_000)) } ?? ""; addSubview(field)
        }
        daily.setAccessibilityLabel(L("Limite por dia de \(value.model) em US$", "\(value.model) daily limit in US$"))
        cycle.setAccessibilityLabel(L("Limite por ciclo de \(value.model) em US$", "\(value.model) cycle limit in US$"))
        let remove = NSButton(image: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: L("Parar de monitorar \(value.model)", "Stop monitoring \(value.model)"))!, target: self, action: #selector(removeAction))
        remove.frame = NSRect(x: 432, y: 5, width: 20, height: 20); remove.isBordered = false; remove.contentTintColor = .secondaryLabelColor; addSubview(remove)
    }
    required init?(coder: NSCoder) { fatalError() }
    func setEnabled(_ enabled: Bool) { daily.isEnabled = enabled; cycle.isEnabled = enabled }
    func setSpend(_ spend: ModelAlertControls.Choice?) {
        daySpent.stringValue = spend.map { MenuBarPresentation.money(Double($0.daySpendMicros)) } ?? "—"
        cycleSpent.stringValue = spend.map { MenuBarPresentation.money(Double($0.cycleSpendMicros)) } ?? "—"
    }
    // Empty means no limit; anything else must be a positive amount.
    func limits() -> (daily: Int64?, cycle: Int64?)? {
        var result: [Int64?] = []
        for field in [daily, cycle] {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            if text.isEmpty { result.append(nil); continue }
            guard let amount = SettingsStyle.dollars(text), amount > 0, amount < 1_000_000_000 else { return nil }
            result.append(Int64((amount * 1_000_000).rounded()))
        }
        return (result[0], result[1])
    }
    func controlTextDidChange(_ notification: Notification) {
        for field in [daily, cycle] {
            let text = field.stringValue.trimmingCharacters(in: .whitespaces)
            field.textColor = text.isEmpty || (SettingsStyle.dollars(text) ?? 0) > 0 ? .labelColor : .systemRed
        }
        onChange?()
    }
    @objc private func removeAction() { onRemove?(self) }
}
