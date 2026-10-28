import AppKit

@MainActor enum QuotaStyle {
    static let background = NSColor(srgbRed: 0.035, green: 0.055, blue: 0.07, alpha: 1)
    static let muted = NSColor(srgbRed: 0.56, green: 0.62, blue: 0.65, alpha: 1)
    static let white = NSColor(calibratedWhite: 0.94, alpha: 1)
    static let mint = NSColor(calibratedRed: 0.49, green: 0.87, blue: 0.73, alpha: 1)
    static func money(_ micros: Double) -> String {
        let f = NumberFormatter(); f.locale = AppLanguage.locale; f.numberStyle = .currency; f.currencyCode = "USD"
        return f.string(from: NSNumber(value: micros / 1_000_000)) ?? "—"
    }
    static func paceMarker(_ pace: QuotaPace?, in rect: NSRect, remaining: Bool) {
        guard let pace else { return }
        white.setFill()
        NSRect(x: rect.minX + rect.width * pace.markerPosition(remaining: remaining), y: rect.minY - 3, width: 1.5, height: rect.height + 6).fill()
    }
    static func tokens(_ value: Int64) -> String {
        if value >= 1_000_000_000 { return localizedDecimal(String(format: "%.2fB", Double(value) / 1_000_000_000)) }
        if value >= 1_000_000 { return localizedDecimal(String(format: "%.1fM", Double(value) / 1_000_000)) }
        if value >= 1000 { return localizedDecimal(String(format: "%.1fk", Double(value) / 1000)) }
        return String(value)
    }
    static func text(_ value: String, rect: NSRect, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor? = nil, align: NSTextAlignment = .left, mono: Bool = false, truncation: NSLineBreakMode = .byTruncatingTail) {
        let p = NSMutableParagraphStyle(); p.lineBreakMode = truncation; p.alignment = align
        (value as NSString).draw(in: rect, withAttributes: [.font: mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color ?? white, .paragraphStyle: p])
    }
}

@MainActor private final class ModelRow: NSView {
    let model: ModelUsage; let share: Double; let pace: Int64?; let showsPace: Bool
    var onHover: ((ModelRow, Bool) -> Void)?
    override var isFlipped: Bool { true }
    init(model: ModelUsage, share: Double, pace: Int64? = nil, showsPace: Bool = false, frame: NSRect) {
        self.model = model; self.share = share; self.pace = pace; self.showsPace = showsPace; super.init(frame: frame)
        setAccessibilityElement(true); setAccessibilityRole(.staticText)
        setAccessibilityLabel("\(model.model), \(QuotaStyle.money(Double(model.costMicros))), \(model.tokens) tokens")
        setAccessibilityHelp(ModelDetailView.lines(for: model, share: share, pace: pace).map { "\($0.0): \($0.1)" }.joined(separator: ", "))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func updateTrackingAreas() {
        super.updateTrackingAreas(); trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(self, true) }
    override func mouseExited(with event: NSEvent) { onHover?(self, false) }
    override func draw(_ dirtyRect: NSRect) {
        // The middle of a long name is the least distinctive part; keep both ends visible.
        QuotaStyle.text(model.model, rect: NSRect(x: 0, y: 2, width: showsPace ? 148 : 178, height: 16), size: 11.5, weight: .medium, truncation: .byTruncatingMiddle)
        let amount = showsPace ? pace.map { QuotaStyle.money(Double($0)) + L("/15 min", "/15 min") } ?? "—" : QuotaStyle.money(Double(model.costMicros))
        QuotaStyle.text(amount, rect: NSRect(x: 150, y: 2, width: 129, height: 16), size: 11.5, weight: .medium, align: .right, mono: true)
        QuotaStyle.text("\(QuotaStyle.tokens(model.tokens))\(model.missingTokenEvents > 0 ? "+" : "") tokens · \(model.events) \(L("requisições", "requests"))", rect: NSRect(x: 0, y: 20, width: 220, height: 14), size: 10, color: QuotaStyle.muted)
        QuotaStyle.text(String(format: "%.0f%%", share * 100), rect: NSRect(x: 226, y: 20, width: 53, height: 14), size: 10, color: QuotaStyle.muted, align: .right)
        NSColor(calibratedWhite: 0.17, alpha: 1).setFill(); NSRect(x: 0, y: 38, width: 279, height: 2).fill()
        QuotaStyle.mint.withAlphaComponent(0.7).setFill(); NSRect(x: 0, y: 38, width: 279 * share, height: 2).fill()
    }
}

// Every number for one model, at a readable size, beside the card while the pointer rests on its row.
@MainActor final class ModelDetailView: NSView {
    static let width: CGFloat = 272
    private var model: ModelUsage?; private var share = 0.0; private var pace: Int64?
    override var isFlipped: Bool { true }
    static func lines(for model: ModelUsage, share: Double, pace: Int64? = nil) -> [(String, String)] {
        let number = { (value: Int64) in value.formatted(.number.locale(AppLanguage.locale)) }
        var lines: [(String, String)] = [(L("Gasto", "Cost"), "\(QuotaStyle.money(Double(model.costMicros))) · \(String(format: "%.0f%%", share * 100))"),
            (L("Requisições", "Requests"), number(Int64(model.events)))]
        if model.events > 0 { lines.append((L("Custo médio por requisição", "Average cost per request"), QuotaStyle.money(Double(model.costMicros) / Double(model.events)))) }
        lines.append((L("Ritmo típico em 15 min", "Usual pace per 15 min"), pace.map { QuotaStyle.money(Double($0)) } ?? L("pouco uso ainda", "not enough use yet")))
        lines += [(L("Tokens informados", "Reported tokens"), number(model.tokens)), (L("Entrada", "Input"), number(model.input)),
                  (L("Gravação em cache", "Cache write"), number(model.cacheWrite)), (L("Leitura de cache", "Cache read"), number(model.cacheRead)), (L("Saída", "Output"), number(model.output))]
        return lines
    }
    private static let nameFont = NSFont.systemFont(ofSize: 13, weight: .semibold)
    private static func nameHeight(_ name: String) -> CGFloat {
        ceil((name as NSString).boundingRect(with: NSSize(width: width - 32, height: 200), options: [.usesLineFragmentOrigin], attributes: [.font: nameFont]).height)
    }
    func show(_ model: ModelUsage, share: Double, pace: Int64? = nil) -> NSSize {
        self.model = model; self.share = share; self.pace = pace; needsDisplay = true
        let note = model.missingTokenEvents > 0 ? 34.0 : 0
        return NSSize(width: Self.width, height: 14 + Self.nameHeight(model.model) + 10 + CGFloat(Self.lines(for: model, share: share, pace: pace).count) * 21 + note + 10)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let model else { return }
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 12, yRadius: 12)
        QuotaStyle.background.setFill(); shape.fill(); NSColor.white.withAlphaComponent(0.12).setStroke(); shape.lineWidth = 1; shape.stroke()
        let nameHeight = Self.nameHeight(model.model)
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byCharWrapping
        (model.model as NSString).draw(in: NSRect(x: 16, y: 14, width: Self.width - 32, height: nameHeight), withAttributes: [.font: Self.nameFont, .foregroundColor: QuotaStyle.white, .paragraphStyle: style])
        var y = 14 + nameHeight + 10
        for (label, value) in Self.lines(for: model, share: share, pace: pace) {
            QuotaStyle.text(label, rect: NSRect(x: 16, y: y, width: 150, height: 17), size: 11.5, color: QuotaStyle.muted)
            QuotaStyle.text(value, rect: NSRect(x: 112, y: y, width: Self.width - 128, height: 17), size: 12, weight: .medium, align: .right, mono: true)
            y += 21
        }
        if model.missingTokenEvents > 0 {
            let text = L("\(model.missingTokenEvents) requisições sem tokens informados pelo Cursor", "\(model.missingTokenEvents) requests without tokens reported by Cursor")
            (text as NSString).draw(in: NSRect(x: 16, y: y + 4, width: Self.width - 32, height: 30), withAttributes: [.font: NSFont.systemFont(ofSize: 10.5), .foregroundColor: QuotaStyle.muted])
        }
    }
}

// A floating panel that never takes focus or clicks, so the card's hover and click behaviour stay unchanged.
@MainActor final class ModelDetailPanel: NSPanel {
    let detail = ModelDetailView(frame: .zero)
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: ModelDetailView.width, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true; level = .popUpMenu; hasShadow = true; backgroundColor = .clear; isOpaque = false; ignoresMouseEvents = true
        appearance = NSAppearance(named: .darkAqua); contentView = detail
    }
    // Beside the card, on whichever side has room, level with the hovered row.
    func show(_ model: ModelUsage, share: Double, pace: Int64? = nil, row: NSRect, card: NSRect, screen: NSRect) {
        let size = detail.show(model, share: share, pace: pace)
        var x = card.minX - size.width - 8
        if x < screen.minX + 4 { x = card.maxX + 8 }
        let y = min(max(row.midY - size.height / 2, screen.minY + 4), screen.maxY - size.height - 4)
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true); orderFront(nil)
    }
}

@MainActor final class QuotaCard: NSView {
    static let size = NSSize(width: 320, height: 396)
    var onConnect: (() -> Void)?; var onRefresh: (() -> Void)?; var onQuit: (() -> Void)?
    var onPeriod: ((UsagePeriod) -> Void)?; var onPreferences: (() -> Void)?
    var onUpdate: (() -> Void)?
    var isPreview = false
    private var snapshot: UsageSnapshot?; private var dataset: UsageDataset?; private var report: AnalyticsReport?
    private var selection = PeriodSelection(); private var stale = false
    private var preferences = AppPreferences()
    private var budget: BudgetAssessment?
    private var message = L("Conecte sua conta", "Connect your account"); private var analyticsMessage = L("Carregando histórico…", "Loading history…")
    private let periodPicker = NSPopUpButton(frame: NSRect(x: 16, y: 106, width: 184, height: 25))
    private let tabs = NSSegmentedControl(labels: ["", "", ""], trackingMode: .selectOne, target: nil, action: nil)
    private let sortPicker = NSSegmentedControl(labels: ["", "", ""], trackingMode: .selectOne, target: nil, action: nil)
    private let modelScroll = OverlayScrollView(frame: NSRect(x: 18, y: 199, width: 284, height: 147))
    private let modelDetail = ModelDetailPanel()
    private var modelSignature = ""
    private var toolButtons: [NSButton] = []
    private let connect = NSButton(title: "", target: nil, action: nil)
    // Stays in the footer until the update is installed, so missing the notification costs nothing.
    private let updateButton = NSButton(title: "", target: nil, action: nil)
    override var isFlipped: Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); appearance = NSAppearance(named: .darkAqua); wantsLayer = true
        layer?.backgroundColor = QuotaStyle.background.cgColor; layer?.cornerRadius = 16
        periodPicker.addItems(withTitles: UsagePeriod.allCases.map(\.title)); periodPicker.font = .systemFont(ofSize: 11, weight: .medium)
        periodPicker.target = self; periodPicker.action = #selector(periodChanged); periodPicker.isBordered = false; addSubview(periodPicker)
        tabs.frame = NSRect(x: 18, y: 140, width: 284, height: 24); tabs.segmentStyle = .rounded; tabs.selectedSegment = 0
        tabs.target = self; tabs.action = #selector(tabChanged); tabs.font = .systemFont(ofSize: 11)
        for index in 0..<3 { tabs.setWidth(94, forSegment: index) }; addSubview(tabs)
        sortPicker.frame = NSRect(x: 122, y: 170, width: 180, height: 22); sortPicker.selectedSegment = 0; sortPicker.target = self; sortPicker.action = #selector(sortChanged)
        sortPicker.toolTip = L("Ordenar do maior para o menor: gasto, tokens ou ritmo (gasto típico em 15 min, o mesmo dos avisos por modelo).", "Sort from highest: cost, tokens or pace (usual spend per 15 min, the same the model alerts use)."); sortPicker.font = .systemFont(ofSize: 10); sortPicker.segmentStyle = .rounded; addSubview(sortPicker)
        modelScroll.drawsBackground = false; modelScroll.fadeColor = QuotaStyle.background; modelScroll.hasVerticalScroller = true; modelScroll.autohidesScrollers = true; addSubview(modelScroll)
        for (name, x, action) in [("gearshape", CGFloat(190), #selector(preferencesAction)), ("arrow.clockwise", CGFloat(222), #selector(refreshAction)), ("person.crop.circle", CGFloat(254), #selector(connectAction)), ("power", CGFloat(286), #selector(quitAction))] {
            let b = NSButton(image: NSImage(systemSymbolName: name, accessibilityDescription: nil)!, target: self, action: action)
            b.frame = NSRect(x: x, y: 363, width: 25, height: 25); b.isBordered = false; b.contentTintColor = QuotaStyle.muted; addSubview(b); toolButtons.append(b)
        }
        connect.target = self; connect.action = #selector(connectAction)
        connect.identifier = NSUserInterfaceItemIdentifier("connect"); connect.frame = NSRect(x: 194, y: 106, width: 113, height: 24)
        connect.isBordered = false; connect.font = .systemFont(ofSize: 10, weight: .medium); connect.contentTintColor = QuotaStyle.mint; addSubview(connect)
        updateButton.identifier = NSUserInterfaceItemIdentifier("update"); updateButton.frame = NSRect(x: 12, y: 363, width: 170, height: 25)
        updateButton.isBordered = false; updateButton.font = .systemFont(ofSize: 11, weight: .semibold); updateButton.contentTintColor = QuotaStyle.mint
        updateButton.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil); updateButton.imagePosition = .imageLeading
        updateButton.alignment = .left; updateButton.target = self; updateButton.action = #selector(updateAction); updateButton.isHidden = true; addSubview(updateButton)
        let mark = NSImageView(frame: NSRect(x: 18, y: 16, width: 18, height: 18)); mark.image = CursorMark.appImage(size: 18, template: false); addSubview(mark)
        localize()
        refreshVisibility()
    }
    // Controls keep their titles until told otherwise, so a language change calls this again.
    func localize() {
        for (index, title) in UsagePeriod.allCases.map(\.title).enumerated() { periodPicker.item(at: index)?.title = title }
        for (index, label) in [L("Resumo", "Summary"), L("Modelos", "Models"), L("Meta", "Goal")].enumerated() { tabs.setLabel(label, forSegment: index) }
        for (index, title) in [L("Gasto", "Cost"), "Tokens", L("Ritmo", "Pace")].enumerated() { sortPicker.setLabel(title, forSegment: index) }
        let tips = [L("Preferências de barra, metas e avisos", "Menu bar, goal and alert preferences"), L("Atualizar dados", "Refresh data"), L("Gerenciar conexão", "Manage connection"), L("Sair", "Quit")]
        for (button, tip) in zip(toolButtons, tips) { button.toolTip = tip; button.setAccessibilityLabel(tip) }
        connect.title = L("Conectar conta", "Connect account")
        needsDisplay = true
    }
    required init?(coder: NSCoder) { fatalError() }
    // Both languages, so a message written before a language change is still recognized.
    static let syncedPrefixes = ["Histórico sincronizado", "History synced"]
    @objc private func preferencesAction() { onPreferences?() }
    @objc private func updateAction() { onUpdate?() }
    func setUpdate(_ version: String?, installing: Bool) {
        updateButton.isHidden = version == nil; updateButton.isEnabled = !installing
        if let version { updateButton.title = installing ? L("Atualizando para \(version)…", "Updating to \(version)…") : L("Atualizar para \(version)", "Update to \(version)") }
        updateButton.setAccessibilityLabel(updateButton.title); needsDisplay = true
    }
    @objc private func connectAction() { onConnect?() }; @objc private func refreshAction() { onRefresh?() }; @objc private func quitAction() { onQuit?() }
    @objc private func periodChanged() {
        let period = UsagePeriod.allCases[periodPicker.indexOfSelectedItem]
        onPeriod?(period)
    }
    @objc private func tabChanged() { hideModelDetail(); refreshVisibility(); needsDisplay = true }
    func hideModelDetail() { modelDetail.orderOut(nil) }
    // Each model's usual 15-minute spend, the pace the model alerts compare; sorted by in the third order.
    private var paces: [String: Int64] = [:]
    func setPaces(_ value: [String: Int64]) { guard value != paces else { return }; paces = value; modelSignature = ""; rebuildModels() }
    @objc private func sortChanged() { modelSignature = ""; rebuildModels(); needsDisplay = true }
    func showModels() { tabs.selectedSegment = 1; tabChanged() }
    func showBudget() { tabs.selectedSegment = 2; tabChanged() }
    func configure(preferences: AppPreferences, budget: BudgetAssessment?) { self.preferences = preferences; self.budget = budget; needsDisplay = true }
    func update(snapshot: UsageSnapshot?, dataset: UsageDataset?, selection: PeriodSelection, stale: Bool, message: String, analyticsMessage: String, now: Date = Date()) {
        self.snapshot = snapshot; self.dataset = dataset; self.selection = selection; self.stale = stale
        self.message = message; self.analyticsMessage = analyticsMessage
        report = dataset.flatMap { AnalyticsEngine.report(dataset: $0, selection: selection, quota: snapshot, now: now) }
        periodPicker.selectItem(at: UsagePeriod.allCases.firstIndex(of: selection.preset)!)
        refreshVisibility(); rebuildModels(); needsDisplay = true
        toolTip = nil
    }
    private var cyclePace: QuotaPace? {
        guard !stale, let snapshot, let budget else { return nil }
        return QuotaPace.estimate(usedFraction: budget.fraction, start: budget.cycle.start, end: budget.cycle.end, observedAt: snapshot.observedAt)
    }
    private func refreshVisibility() {
        let models = tabs.selectedSegment == 1; sortPicker.isHidden = !models; modelScroll.isHidden = !models
        subviews.first { $0.identifier?.rawValue == "connect" }?.isHidden = snapshot != nil
    }
    private func rebuildModels() {
        var rows = report?.models ?? []
        if sortPicker.selectedSegment == 1 { rows.sort { $0.tokens == $1.tokens ? $0.model < $1.model : $0.tokens > $1.tokens } }
        // Pace order: the fastest usual 15 minutes first; models without enough use go last, by cost.
        if sortPicker.selectedSegment == 2 { rows.sort { (paces[$0.model] ?? -1, $0.costMicros) > (paces[$1.model] ?? -1, $1.costMicros) } }
        let signature = rows.map { "\($0.model):\($0.costMicros):\($0.tokens):\(paces[$0.model] ?? -1)" }.joined() + "\(sortPicker.selectedSegment)"
        guard signature != modelSignature else { return }; modelSignature = signature
        let document = FlippedContent(frame: NSRect(x: 0, y: 0, width: 279, height: max(147, rows.count * 44)))
        let total = max(1, report?.costMicros ?? 0)
        hideModelDetail()
        for (index, row) in rows.enumerated() {
            let view = ModelRow(model: row, share: Double(row.costMicros) / Double(total), pace: paces[row.model], showsPace: sortPicker.selectedSegment == 2,
                                frame: NSRect(x: 0, y: index * 44, width: 279, height: 44))
            view.onHover = { [weak self] row, inside in self?.hover(row, inside: inside) }; document.addSubview(view)
        }
        modelScroll.documentView = document
    }
    private func hover(_ row: ModelRow, inside: Bool) {
        guard inside, let window, !isHidden, let screen = window.screen?.visibleFrame else { hideModelDetail(); return }
        modelDetail.show(row.model, share: row.share, pace: row.pace, row: window.convertToScreen(row.convert(row.bounds, to: nil)), card: window.frame, screen: screen)
    }
    private func text(_ value: String, x: CGFloat = 18, y: CGFloat, width: CGFloat = 284, size: CGFloat = 10, weight: NSFont.Weight = .regular, color: NSColor? = nil, align: NSTextAlignment = .left, mono: Bool = false) {
        QuotaStyle.text(value, rect: NSRect(x: x, y: y, width: width, height: 32), size: size, weight: weight, color: color, align: align, mono: mono)
    }
    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 16, yRadius: 16)
        NSGradient(starting: NSColor(srgbRed: 0.075, green: 0.12, blue: 0.14, alpha: 1), ending: QuotaStyle.background)?.draw(in: background, angle: 90)
        NSColor.white.withAlphaComponent(0.08).setStroke(); background.lineWidth = 1; background.stroke()
        NSColor.white.withAlphaComponent(0.025).setFill(); NSBezierPath(roundedRect: NSRect(x: 10, y: 170, width: 300, height: 181), xRadius: 12, yRadius: 12).fill()
        text("Cursor Usage", x: 42, y: 16, width: 134, size: 13, weight: .semibold)
        text(isPreview ? L("PRÉVIA", "PREVIEW") : snapshot.flatMap { $0.isIncludedPercent ? L("PLANO PESSOAL", "PERSONAL PLAN") : nil } ?? snapshot.map { String(format: preferences.cursorUsageBasis == .used ? L("%.1f%% usado", "%.1f%% used") : L("%.1f%% disponível", "%.1f%% available"), (preferences.cursorUsageBasis == .used ? $0.usedFraction : max(0, 1 - $0.usedFraction)) * 100) } ?? L("SEM CONEXÃO", "NOT CONNECTED"), x: 180, y: 19, width: 122, size: 10, color: QuotaStyle.muted, align: .right)
        text(snapshot.map { $0.isIncludedPercent ? Self.percent(preferences.cursorUsageBasis == .used ? $0.usedFraction : max(0, 1 - $0.usedFraction)) : QuotaStyle.money(Double(preferences.cursorUsageBasis == .used ? $0.spentCents : $0.remainingCents) * 10_000) } ?? "—", y: 43, width: 180, size: 22, weight: .medium, mono: true)
        text(preferences.cursorUsageBasis == .used ? L("consumidos", "used") : L("disponíveis", "available"), x: 196, y: 51, width: 106, size: 10, color: QuotaStyle.muted, align: .right)
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: 18, y: 77, width: 284, height: 4), xRadius: 2, yRadius: 2).fill()
        (stale ? QuotaStyle.muted : cyclePace?.exceedsQuota == true ? NSColor.systemOrange : QuotaStyle.mint).setFill(); NSBezierPath(roundedRect: NSRect(x: 18, y: 77, width: 284 * min(1, snapshot.map { preferences.cursorUsageBasis == .used ? $0.usedFraction : max(0, 1 - $0.usedFraction) } ?? 0), height: 4), xRadius: 2, yRadius: 2).fill()
        QuotaStyle.paceMarker(cyclePace, in: NSRect(x: 18, y: 77, width: 284, height: 4), remaining: preferences.cursorUsageBasis == .remaining)
        let resetFormatter = DateFormatter(); resetFormatter.locale = AppLanguage.locale; resetFormatter.timeZone = TimeZone(secondsFromGMT: 0); resetFormatter.dateFormat = "d MMM"
        if let snapshot, snapshot.isIncludedPercent {
            let extra = snapshot.onDemandSpentCents.map { L(" · extra \(QuotaStyle.money(Double($0) * 10_000))", " · extra \(QuotaStyle.money(Double($0) * 10_000))") } ?? ""
            text(L("Cota incluída · renova \(resetFormatter.string(from: snapshot.resetDate))\(extra)", "Included usage · renews \(resetFormatter.string(from: snapshot.resetDate))\(extra)"), y: 87, size: 8.5, color: QuotaStyle.muted)
        } else {
        text(snapshot.map { L("\(QuotaStyle.money(Double($0.spentCents) * 10_000)) de \(QuotaStyle.money(Double($0.limitCents) * 10_000)) · renova \(resetFormatter.string(from: $0.resetDate))", "\(QuotaStyle.money(Double($0.spentCents) * 10_000)) of \(QuotaStyle.money(Double($0.limitCents) * 10_000)) · renews \(resetFormatter.string(from: $0.resetDate))") } ?? message, y: 87, size: 8.5, color: QuotaStyle.muted)
        }
        if tabs.selectedSegment == 0 { drawSummary() }
        else if tabs.selectedSegment == 2 { drawBudget() }
        else {
            text(L("MODELOS · \(report?.models.count ?? 0)", "MODELS · \(report?.models.count ?? 0)"), y: 175, width: 100, size: 9, weight: .medium, color: QuotaStyle.muted)
            if report?.models.isEmpty ?? true { text(report == nil ? analyticsMessage : L("Nenhuma requisição neste período", "No requests in this period"), y: 222, size: 11, color: QuotaStyle.muted) }
        }
        NSColor(calibratedWhite: 0.17, alpha: 1).setFill(); NSRect(x: 18, y: 355, width: 284, height: 1).fill()
        let footer: String
        if isPreview { footer = L("Prévia · leitura anterior", "Preview · previous reading") }
        else if !QuotaCard.syncedPrefixes.contains(where: { analyticsMessage.hasPrefix($0) }) { footer = analyticsMessage }
        else if let dataset, report != nil { let f = DateFormatter(); f.dateFormat = "HH:mm"; footer = "\(stale ? L("Leitura anterior", "Previous reading") : L("Atualizado", "Updated")) \(f.string(from: dataset.fetchedAt))" }
        else { footer = analyticsMessage }
        if updateButton.isHidden { text(footer, y: 370, width: 169, size: 9, color: QuotaStyle.muted) }
    }
    static func percent(_ fraction: Double) -> String { localizedDecimal(String(format: fraction * 100 < 1 && fraction > 0 ? "%.1f%%" : "%.0f%%", fraction * 100)) }
    // A personal plan: the share of its included usage, then any money spent beyond it on demand.
    private func drawIncluded(_ budget: BudgetAssessment) {
        let resetFormatter = DateFormatter(); resetFormatter.locale = AppLanguage.locale; resetFormatter.timeZone = TimeZone(secondsFromGMT: 0); resetFormatter.dateFormat = "d MMM"
        text(L("COTA INCLUÍDA DO PLANO", "PLAN'S INCLUDED USAGE"), y: 176, size: 9, weight: .medium, color: QuotaStyle.muted)
        text(L("\(Self.percent(budget.fraction)) usada", "\(Self.percent(budget.fraction)) used"), y: 194, size: 16, weight: .medium, mono: true)
        text(L("renova \(resetFormatter.string(from: budget.cycle.end))", "renews \(resetFormatter.string(from: budget.cycle.end))"), x: 170, y: 199, width: 132, size: 10, color: QuotaStyle.muted, align: .right)
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); NSRect(x: 18, y: 215, width: 284, height: 5).fill()
        (budget.fraction >= 1 ? NSColor.systemOrange : QuotaStyle.mint).setFill(); NSRect(x: 18, y: 215, width: 284 * min(1, budget.fraction), height: 5).fill()
        if preferences.notifyCycle { NSColor.systemOrange.setFill(); NSRect(x: 18 + 284 * Double(preferences.alertPercent) / 100, y: 212, width: 1, height: 11).fill() }
        QuotaStyle.paceMarker(cyclePace, in: NSRect(x: 18, y: 215, width: 284, height: 5), remaining: false)
        if let pace = cyclePace { text("\(pace.label) · \(L("estimativa linear", "linear estimate"))", y: 224, size: 8, color: pace.exceedsQuota ? .systemOrange : QuotaStyle.muted) }
        // Money beyond the included usage, when the plan allows it.
        text(L("DINHEIRO EXTRA · SOB DEMANDA", "EXTRA MONEY · ON DEMAND"), y: 248, size: 9, weight: .medium, color: QuotaStyle.muted)
        if let spent = snapshot?.onDemandSpentCents, let limit = snapshot?.onDemandLimitCents {
            let fraction = Double(spent) / Double(limit)
            text(L("\(QuotaStyle.money(Double(spent) * 10_000)) de \(QuotaStyle.money(Double(limit) * 10_000))", "\(QuotaStyle.money(Double(spent) * 10_000)) of \(QuotaStyle.money(Double(limit) * 10_000))"), y: 264, size: 14, weight: .medium, mono: true)
            NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); NSRect(x: 18, y: 288, width: 284, height: 3).fill()
            (fraction >= 0.9 ? NSColor.systemOrange : QuotaStyle.mint).setFill(); NSRect(x: 18, y: 288, width: 284 * min(1, fraction), height: 3).fill()
            text(L("Limite que você definiu no Cursor para gastar além da cota.", "The limit you set in Cursor for spending beyond the quota."), y: 298, size: 9, color: QuotaStyle.muted)
        } else {
            text(L("Nenhum dinheiro extra ligado.", "No extra money turned on."), y: 264, size: 11, weight: .medium)
            text(L("Em 100% o uso pausa até renovar. Nos planos pagos, ligue em Spending.", "At 100% usage pauses until it renews. Paid plans can turn it on under Spending."), y: 282, size: 10, color: QuotaStyle.muted)
        }
        text(preferences.notifyCycle ? L("Aviso aos \(preferences.alertPercent)% da cota", "Alert at \(preferences.alertPercent)% of the quota") : L("Avisos desligados · personalize na engrenagem", "Alerts off · customize under the gear"), y: 338, size: 8, color: QuotaStyle.muted)
    }
    private func drawBudget() {
        if let budget, budget.isIncludedPercent { drawIncluded(budget); return }
        guard let budget else { text(L("Sincronize a conta para calcular a meta.", "Sync the account to calculate the goal."), y: 200, size: 11, color: QuotaStyle.muted); return }
        text(preferences.personalBudgetEnabled ? L("SUA META NO CICLO", "YOUR CYCLE GOAL") : L("COTA OFICIAL DO CICLO", "OFFICIAL CYCLE QUOTA"), y: 176, size: 9, weight: .medium, color: QuotaStyle.muted)
        text("\(QuotaStyle.money(Double(budget.spentMicros))) / \(QuotaStyle.money(Double(budget.targetMicros)))", y: 194, size: 16, weight: .medium, mono: true)
        NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); NSRect(x: 18, y: 215, width: 284, height: 5).fill()
        (budget.fraction >= 1 ? NSColor.systemOrange : QuotaStyle.mint).setFill(); NSRect(x: 18, y: 215, width: 284 * min(1, budget.fraction), height: 5).fill()
        if preferences.notifyCycle { NSColor.systemOrange.setFill(); NSRect(x: 18 + 284 * Double(preferences.alertPercent) / 100, y: 212, width: 1, height: 11).fill() }
        QuotaStyle.paceMarker(cyclePace, in: NSRect(x: 18, y: 215, width: 284, height: 5), remaining: false)
        if let pace = cyclePace { text("\(pace.label) · \(L("estimativa linear", "linear estimate"))", y: 224, size: 8, color: pace.exceedsQuota ? .systemOrange : QuotaStyle.muted) }
        text(L("HOJE · COTA DIÁRIA AJUSTADA", "TODAY · ADJUSTED DAILY QUOTA"), y: 239, size: 9, weight: .medium, color: QuotaStyle.muted)
        if let daily = budget.dailyLimitMicros, let spent = budget.todaySpentMicros {
            text("\(QuotaStyle.money(Double(spent))) / \(QuotaStyle.money(daily))", y: 255, size: 14, weight: .medium, mono: true)
            NSColor(calibratedWhite: 0.18, alpha: 1).setFill(); NSRect(x: 18, y: 279, width: 284, height: 3).fill()
            (budget.overDailyLimit ? NSColor.systemOrange : QuotaStyle.mint).setFill()
            NSRect(x: 18, y: 279, width: daily > 0 ? 284 * min(1, Double(spent) / daily) : (spent > 0 ? 284 : 0), height: 3).fill()
            if preferences.notifyDaily { NSColor.systemOrange.setFill(); NSRect(x: 18 + 284 * preferences.dailyAlertPercent / 100, y: 276, width: 1, height: 9).fill() }
            text(budget.overDailyLimit ? L("Cota diária ultrapassada", "Daily quota exceeded") : L("Ainda hoje: \(QuotaStyle.money(budget.remainingTodayMicros ?? 0))", "Left today: \(QuotaStyle.money(budget.remainingTodayMicros ?? 0))"), y: 292, size: 11, weight: .medium, color: budget.overDailyLimit ? .systemOrange : QuotaStyle.mint)
        } else { text(L("Histórico diário ainda indisponível", "Daily history not available yet"), y: 255, size: 11, color: QuotaStyle.muted) }
        let guidance = budget.remainingMicros == 0 ? L("Meta atingida: evite consumo adicional.", "Goal reached: avoid further usage.") : budget.requiredSavingMicros > 0 ? L("Economize \(QuotaStyle.money(budget.requiredSavingMicros))/dia para a meta.", "Save \(QuotaStyle.money(budget.requiredSavingMicros))/day to meet the goal.") : L("Ritmo na meta · até \(QuotaStyle.money(budget.recommendedDailyMicros))/dia.", "On pace · up to \(QuotaStyle.money(budget.recommendedDailyMicros))/day.")
        text(guidance, y: 314, size: 10, color: budget.requiredSavingMicros > 0 ? .systemOrange : QuotaStyle.muted)
        let alerts = [preferences.notifyCycle ? L("Aviso aos \(preferences.alertPercent)%", "Alert at \(preferences.alertPercent)%") : nil, preferences.notifyDaily ? String(format: L("Diário aos %.0f%%", "Daily at %.0f%%"), preferences.dailyAlertPercent) : nil].compactMap { $0 }
        text(alerts.isEmpty ? L("Avisos desligados · personalize na engrenagem", "Alerts off · customize under the gear") : alerts.joined(separator: " · "), y: 338, size: 8, color: QuotaStyle.muted)
    }
    private func drawSummary() {
        guard let report else { text(analyticsMessage, y: 202, size: 11, color: QuotaStyle.muted); return }
        text(QuotaStyle.money(Double(report.costMicros)), y: 177, width: 185, size: 25, weight: .medium, mono: true)
        text(L("no período", "in the period"), x: 209, y: 190, width: 93, size: 9, color: QuotaStyle.muted, align: .right)
        text("\(QuotaStyle.tokens(report.tokens))\(report.missingTokenEvents > 0 ? "+" : "") tokens · \(report.eventCount) \(L("requisições", "requests"))", y: 211, size: 10, color: QuotaStyle.muted)
        if report.missingTokenEvents > 0 { text(L("\(report.missingTokenEvents) sem tokens", "\(report.missingTokenEvents) without tokens"), x: 205, y: 212, width: 97, size: 8, color: QuotaStyle.muted, align: .right) }
        let bucketSize = max(1, Int(ceil(Double(report.daily.count) / 28)))
        let buckets = stride(from: 0, to: report.daily.count, by: bucketSize).map { start in report.daily[start..<min(report.daily.count, start + bucketSize)].reduce(Int64(0)) { $0 + $1.costMicros } }
        let count = max(1, buckets.count), maxCost = max(1, buckets.max() ?? 1), step = 284 / CGFloat(max(1, buckets.count))
        for (index, cost) in buckets.enumerated() {
            let height = max(1, 25 * CGFloat(cost) / CGFloat(maxCost)); QuotaStyle.mint.withAlphaComponent(index == count - 1 ? 0.95 : 0.45).setFill()
            NSBezierPath(roundedRect: NSRect(x: 18 + CGFloat(index) * step, y: 255 - height, width: max(1, step - 3), height: height), xRadius: 1.5, yRadius: 1.5).fill()
        }
        let axis = DateFormatter(); axis.locale = AppLanguage.locale; axis.dateFormat = "d MMM"
        if let first = report.daily.first, let last = report.daily.last {
            text(axis.string(from: first.date), y: 257, width: 80, size: 7, color: QuotaStyle.muted)
            text(axis.string(from: last.date), x: 222, y: 257, width: 80, size: 7, color: QuotaStyle.muted, align: .right)
        }
        if let p = report.projection {
            text(L("RITMO DO PERÍODO", "PERIOD PACE"), y: 270, width: 140, size: 8, color: QuotaStyle.muted); text(L("PARA A META / DIA", "FOR THE GOAL / DAY"), x: 168, y: 270, width: 134, size: 8, color: QuotaStyle.muted)
            text("\(QuotaStyle.money(p.dailyMicros))/\(L("dia", "day"))", y: 286, width: 146, size: 13, weight: .medium, color: p.dailyMicros > p.safeDailyMicros ? .systemOrange : nil, mono: true)
            text(QuotaStyle.money(budget?.recommendedDailyMicros ?? p.safeDailyMicros), x: 168, y: 286, width: 134, size: 13, weight: .medium, color: QuotaStyle.mint, mono: true)
            text(L("Projeção do ciclo", "Cycle projection"), y: 319, width: 170, size: 10, color: QuotaStyle.muted)
            let projected = cyclePace.flatMap { pace in budget.map { pace.projectedFraction * Double($0.targetMicros) } }
            text(projected.map(QuotaStyle.money) ?? "—", x: 183, y: 315, width: 119, size: 14, weight: .medium, color: cyclePace?.exceedsQuota == true ? .systemOrange : nil, align: .right, mono: true)
            text(cyclePace.map { "\($0.label) · \(L("estimativa linear", "linear estimate"))" } ?? L("Ritmo do ciclo ainda indisponível", "Cycle pace not available yet"), y: 338, size: 8, color: cyclePace?.exceedsQuota == true ? .systemOrange : QuotaStyle.muted)
        }
    }
}

@MainActor private final class FlippedContent: NSView { override var isFlipped: Bool { true } }

@MainActor func statusIcon(fraction: Double?, stale: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 17, height: 17), flipped: false) { rectangle in
        let ring = NSBezierPath(ovalIn: rectangle.insetBy(dx: 2, dy: 2)); ring.lineWidth = 2; NSColor.labelColor.withAlphaComponent(0.25).setStroke(); ring.stroke()
        if let fraction {
            let arc = NSBezierPath(); arc.lineWidth = 2; arc.lineCapStyle = .round
            arc.appendArc(withCenter: NSPoint(x: 8.5, y: 8.5), radius: 6.5, startAngle: 90, endAngle: 90 - min(1, max(0, fraction)) * 360, clockwise: true)
            NSColor.labelColor.setStroke(); arc.stroke()
        } else { NSColor.labelColor.setFill(); NSRect(x: 5, y: 8, width: 7, height: 1).fill() }
        if stale { NSColor.labelColor.setFill(); NSBezierPath(ovalIn: NSRect(x: 12, y: 0, width: 4, height: 4)).fill() }; return true
    }
    image.isTemplate = true; return image
}
