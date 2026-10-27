import AppKit

// Per-model alerts in settings: a model's first use, spending above the costliest model, and goals for chosen models.
@MainActor final class ModelAlertControls: NSView, NSTextFieldDelegate {
    struct Draft: Equatable { var notifyNewModel = true; var notifyRate = true; var ratePercent = 50; var monitored: [MonitoredModel] = [] }
    struct Choice: Equatable { let model: String; let cycleSpendMicros: Int64; let isNew: Bool }
    var onChange: (() -> Void)?
    var onResize: (() -> Void)?
    private let newModel = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rate = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let rateThreshold = NSSlider(value: 50, minValue: 10, maxValue: 300, target: nil, action: nil)
    private let rateDescription = NSTextField(labelWithString: "")
    private let add = NSButton(title: "", target: nil, action: nil)
    private let empty = NSTextField(wrappingLabelWithString: "")
    private let footnote = NSTextField(wrappingLabelWithString: "")
    private var rows: [LimitRow] = []
    private var choices: [Choice] = []
    private static let listTop: CGFloat = 230, rowHeight: CGFloat = 30
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(x: SettingsStyle.inset, y: 0, width: 452, height: 300))
        SettingsStyle.separator(in: self, x: 0, y: 0)
        SettingsStyle.header(L("Avisos por modelo", "Per-model alerts"), in: self, x: 0, y: 14)
        newModel.title = L("Avisar quando um modelo for usado pela primeira vez", "Notify when a model is used for the first time")
        newModel.frame = NSRect(x: 0, y: 42, width: 452, height: 22)
        SettingsStyle.note(L("Pega o teste de um modelo novo logo na sincronização seguinte.", "Catches a new model being tried at the next sync."), in: self, x: 22, y: 66, width: 430)
        rate.frame = NSRect(x: 0, y: 94, width: 452, height: 22)
        rateThreshold.frame = NSRect(x: 22, y: 122, width: 200, height: 22); rateThreshold.numberOfTickMarks = 0
        rateDescription.frame = NSRect(x: 236, y: 122, width: 216, height: 22); rateDescription.font = .systemFont(ofSize: 11)
        SettingsStyle.note(L("Compara o gasto dos últimos 15 minutos com o gasto típico do seu modelo mais caro nos últimos 14 dias.", "Compares the last 15 minutes of spending with your costliest model's usual 15 minutes over the past 14 days."), in: self, x: 22, y: 148, width: 430, height: 30)
        SettingsStyle.header(L("Modelos monitorados", "Monitored models"), in: self, x: 0, y: 186, size: 12)
        for (title, x, width, align) in [(L("Modelo", "Model"), CGFloat(0), CGFloat(190), NSTextAlignment.left), (L("No ciclo", "This cycle"), 196, 84, .right),
                                         (L("Limite/dia", "Limit/day"), 288, 66, .left), (L("Limite/ciclo", "Limit/cycle"), 360, 66, .left)] {
            let label = NSTextField(labelWithString: title); label.frame = NSRect(x: x, y: 210, width: width, height: 16)
            label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor; label.alignment = align; addSubview(label)
        }
        empty.stringValue = L("Nenhum modelo monitorado. Escolha um com o botão abaixo.", "No monitored models. Pick one with the button below.")
        empty.font = .systemFont(ofSize: 11); empty.textColor = .secondaryLabelColor
        add.title = L("Monitorar modelo…", "Monitor a model…"); add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        add.imagePosition = .imageLeading; add.bezelStyle = .rounded; add.font = .systemFont(ofSize: 12); add.target = self; add.action = #selector(showChoices)
        footnote.stringValue = L("Os limites são metas suas. A cota do Cursor é uma só para todos os modelos.", "Limits are your own goals. Cursor's allowance is shared by every model.")
        footnote.font = .systemFont(ofSize: 11); footnote.textColor = .secondaryLabelColor
        for control in [newModel, rate] { control.font = .systemFont(ofSize: 12); control.target = self; control.action = #selector(changed); addSubview(control) }
        rateThreshold.target = self; rateThreshold.action = #selector(changed)
        for view in [rateThreshold, rateDescription, empty, add, footnote] { addSubview(view) }
        relayout()
    }
    required init?(coder: NSCoder) { fatalError() }

    func present(_ value: Draft, choices: [Choice]) {
        self.choices = choices
        newModel.state = value.notifyNewModel ? .on : .off; rate.state = value.notifyRate ? .on : .off; rateThreshold.integerValue = value.ratePercent
        rows.forEach { $0.removeFromSuperview() }; rows = []
        value.monitored.forEach(append); relayout(); refresh()
    }
    func draft() -> Draft? {
        var value = Draft(notifyNewModel: newModel.state == .on, notifyRate: rate.state == .on, ratePercent: rateThreshold.integerValue)
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

    private func append(_ value: MonitoredModel) {
        let row = LimitRow(value, spend: choices.first { $0.model == value.model }?.cycleSpendMicros, frame: NSRect(x: 0, y: 0, width: 452, height: Self.rowHeight))
        row.onChange = { [weak self] in self?.onChange?() }
        row.onRemove = { [weak self] row in self?.rows.removeAll { $0 === row }; row.removeFromSuperview(); self?.relayout(); self?.onChange?() }
        rows.append(row); addSubview(row)
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
    private func refresh() {
        let percent = rateThreshold.integerValue
        rate.title = L("Avisar quando um modelo gastar \(percent)% acima do seu modelo mais caro", "Notify when a model spends \(percent)% above your costliest model")
        rateDescription.stringValue = L("\(percent)% acima · janelas de 15 min", "\(percent)% above · 15-minute windows")
        rateThreshold.isEnabled = rate.state == .on
    }
    @objc private func changed() { refresh(); onChange?() }
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
    private let daily = NSTextField(), cycle = NSTextField()
    override var isFlipped: Bool { true }
    init(_ value: MonitoredModel, spend: Int64?, frame: NSRect) {
        model = value.model; super.init(frame: frame)
        let name = NSTextField(labelWithString: value.model); name.frame = NSRect(x: 0, y: 6, width: 190, height: 18)
        name.font = .monospacedSystemFont(ofSize: 11, weight: .regular); name.lineBreakMode = .byTruncatingMiddle; name.toolTip = value.model; addSubview(name)
        let spent = NSTextField(labelWithString: spend.map { MenuBarPresentation.money(Double($0)) } ?? "—"); spent.frame = NSRect(x: 196, y: 6, width: 84, height: 18)
        spent.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); spent.textColor = .secondaryLabelColor; spent.alignment = .right; addSubview(spent)
        for (field, x, micros) in [(daily, CGFloat(288), value.dailyLimitMicros), (cycle, 360, value.cycleLimitMicros)] {
            field.frame = NSRect(x: x, y: 3, width: 66, height: 24); field.font = .systemFont(ofSize: 11); field.placeholderString = "—"; field.delegate = self
            field.stringValue = micros.map { localizedDecimal(String(format: "%.2f", Double($0) / 1_000_000)) } ?? ""; addSubview(field)
        }
        daily.setAccessibilityLabel(L("Limite por dia de \(value.model) em US$", "\(value.model) daily limit in US$"))
        cycle.setAccessibilityLabel(L("Limite por ciclo de \(value.model) em US$", "\(value.model) cycle limit in US$"))
        let remove = NSButton(image: NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: L("Parar de monitorar \(value.model)", "Stop monitoring \(value.model)"))!, target: self, action: #selector(removeAction))
        remove.frame = NSRect(x: 432, y: 5, width: 20, height: 20); remove.isBordered = false; remove.contentTintColor = .secondaryLabelColor; addSubview(remove)
    }
    required init?(coder: NSCoder) { fatalError() }
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
