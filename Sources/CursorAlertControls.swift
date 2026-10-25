import AppKit

struct QuotaAlertDraft {
    var personalEnabled = false
    var personalLimit: Double = 0
    var cycleEnabled = false
    var cyclePercent = 80
    var dailyEnabled = false
    var dailyPercent: Double = 100
    var sound = false
    var renewal = false
}

// Cursor spending goals, daily allowance and native alerts.
@MainActor final class CursorAlertControls: NSView, NSTextFieldDelegate {
    static let height: CGFloat = 408
    var onChange: (() -> Void)?
    private var initial = QuotaAlertDraft()
    private var officialLimit: Double?
    private var allowance: Double?
    private var dailyInputValid = true
    private let personal = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let limit = NSTextField()
    private let cycle = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let cycleThreshold = NSSlider(value: 80, minValue: 1, maxValue: 100, target: nil, action: nil)
    private let cycleDescription = NSTextField(labelWithString: "")
    private let daily = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let dailyThreshold = NSSlider(value: 100, minValue: 1, maxValue: 100, target: nil, action: nil)
    private let dailyRatio = NSTextField(labelWithString: "")
    private let dailyAmount = NSTextField()
    private let dailyDescription = NSTextField(wrappingLabelWithString: "")
    private let sound = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let renewal = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(x: 22, y: 0, width: 400, height: Self.height))
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat = 400, _ size: CGFloat = 11) {
            let item = NSTextField(labelWithString: text); item.frame = NSRect(x: x, y: y, width: width, height: 22)
            item.font = .systemFont(ofSize: size); addSubview(item)
        }
        label(L("Meta e avisos do Cursor", "Cursor goal and alerts"), 0, 0, 250, 13)
        personal.title = L("Definir um limite pessoal de gastos", "Set a personal spending limit")
        personal.frame = NSRect(x: 0, y: 28, width: 400, height: 22)
        label(L("Limite em", "Limit in") + (" US$"), 0, 62, 116)
        limit.frame = NSRect(x: 121, y: 58, width: 164, height: 26)
        limit.placeholderString = L("Ex.: 500,00", "E.g. 500.00")
        limit.delegate = self; addSubview(limit)
        label(L("Não altera o limite contratado com o Cursor.", "Does not change your Cursor plan limit."), 121, 88, 279, 10)
        cycle.title = L("Avisar ao consumir 80% do limite", "Notify at 80% of the limit")
        cycle.frame = NSRect(x: 0, y: 122, width: 400, height: 22)
        cycleThreshold.frame = NSRect(x: 0, y: 152, width: 192, height: 22)
        cycleDescription.frame = NSRect(x: 205, y: 152, width: 195, height: 22); cycleDescription.font = .systemFont(ofSize: 11)
        label(L("Usa seu limite pessoal ou a cota do Cursor.", "Uses your personal limit or the Cursor allowance."), 0, 181, 400, 10)
        daily.title = L("Notificar ao atingir esta % da cota diária", "Notify at this % of the daily allowance")
        daily.frame = NSRect(x: 0, y: 212, width: 400, height: 22)
        dailyThreshold.frame = NSRect(x: 0, y: 242, width: 150, height: 24)
        dailyRatio.frame = NSRect(x: 159, y: 246, width: 47, height: 22); dailyRatio.font = .systemFont(ofSize: 11)
        label("US$", 209, 243, 30)
        dailyAmount.frame = NSRect(x: 246, y: 242, width: 154, height: 24); dailyAmount.delegate = self
        dailyAmount.placeholderString = L("Após sincronizar", "After syncing")
        dailyAmount.toolTip = L("O aviso acompanha a cota diária calculada sem alterar sua meta.", "The alert follows the calculated daily quota without changing your goal.")
        dailyDescription.frame = NSRect(x: 0, y: 278, width: 400, height: 54); dailyDescription.font = .systemFont(ofSize: 10)
        dailyDescription.textColor = .secondaryLabelColor
        sound.title = L("Tocar som junto às notificações", "Play a sound with notifications"); sound.frame = NSRect(x: 0, y: 340, width: 400, height: 22)
        renewal.title = L("Avisar quando uma cota for renovada", "Alert when a quota renews")
        renewal.frame = NSRect(x: 0, y: 370, width: 400, height: 22)
        for control in [personal, cycle, daily, sound, renewal] {
            control.font = .systemFont(ofSize: 11); control.target = self; control.action = #selector(changed); addSubview(control)
        }
        for control in [cycleThreshold, dailyThreshold] { control.target = self; control.action = #selector(changed); addSubview(control) }
        for view in [cycleDescription, dailyRatio, dailyAmount, dailyDescription] { addSubview(view) }
    }
    required init?(coder: NSCoder) { fatalError() }

    func present(_ value: QuotaAlertDraft, officialLimit: Double?) {
        initial = value; self.officialLimit = officialLimit; dailyInputValid = true
        personal.state = value.personalEnabled ? .on : .off
        limit.stringValue = value.personalLimit > 0 ? localizedDecimal(String(format: "%.2f", value.personalLimit)) : ""
        cycle.state = value.cycleEnabled ? .on : .off; cycleThreshold.integerValue = value.cyclePercent
        daily.state = value.dailyEnabled ? .on : .off; dailyThreshold.doubleValue = value.dailyPercent
        sound.state = value.sound ? .on : .off; renewal.state = value.renewal ? .on : .off
        refreshAppearance()
    }
    func draft() -> QuotaAlertDraft? {
        var value = initial
        value.personalEnabled = personal.state == .on
        if value.personalEnabled {
            guard let amount = number(limit.stringValue), amount > 0, amount < 1_000_000_000 else { return nil }
            value.personalLimit = amount
        }
        guard daily.state != .on || dailyInputValid else { return nil }
        value.cycleEnabled = cycle.state == .on; value.cyclePercent = cycleThreshold.integerValue
        value.dailyEnabled = daily.state == .on; value.dailyPercent = dailyThreshold.doubleValue
        value.sound = sound.state == .on; value.renewal = renewal.state == .on
        return value
    }
    func setAssessment(allowance: Double?, todayUsed: Double?, observedSince: Date?) {
        self.allowance = allowance
        if let allowance {
            dailyDescription.stringValue = L("Cota diária calculada: ", "Calculated daily quota: ") + format(allowance)
            if let todayUsed { dailyDescription.stringValue += L(" · Uso hoje: ", " · Usage today: ") + format(todayUsed) }
            if let since = observedSince {
                let formatter = DateFormatter(); formatter.locale = AppLanguage.locale; formatter.timeStyle = .short
                dailyDescription.stringValue += L("\nObservado desde \(formatter.string(from: since)); sem consumo retroativo.", "\nObserved since \(formatter.string(from: since)); no retroactive usage.")
            }
        } else { dailyDescription.stringValue = L("Sincronize a cota para calcular o valor diário. Os avisos são opcionais.", "Sync the quota to calculate the daily amount. Alerts are optional.") }
        refreshAppearance()
    }
    private func number(_ text: String) -> Double? {
        let raw = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard raw.range(of: #"^[0-9]+(?:\.[0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let result = Double(raw), result.isFinite else { return nil }
        return result
    }
    private func format(_ value: Double) -> String {
        MenuBarPresentation.money(value * 1_000_000)
    }
    private func refreshAppearance() {
        limit.isEnabled = personal.state == .on; cycleThreshold.isEnabled = cycle.state == .on
        dailyThreshold.isEnabled = daily.state == .on; dailyAmount.isEnabled = daily.state == .on && (allowance ?? 0) > 0
        sound.isEnabled = cycle.state == .on || daily.state == .on || renewal.state == .on
        dailyAmount.textColor = dailyInputValid ? .labelColor : .systemRed
        limit.textColor = personal.state == .on && (number(limit.stringValue) ?? 0) <= 0 ? .systemRed : .labelColor
        dailyRatio.stringValue = localizedDecimal(String(format: "%.1f%%", dailyThreshold.doubleValue))
        if let allowance, dailyInputValid { dailyAmount.stringValue = localizedDecimal(String(format: "%.2f", allowance * dailyThreshold.doubleValue / 100)) }
        else if allowance == nil && dailyInputValid { dailyAmount.stringValue = "" }
        cycle.title = L("Avisar ao consumir \(cycleThreshold.integerValue)% do limite", "Notify at \(cycleThreshold.integerValue)% of the limit")
        let target = personal.state == .on ? number(limit.stringValue) : officialLimit
        cycleDescription.stringValue = "\(cycleThreshold.integerValue)%" + (target.map { " · " + format($0 * Double(cycleThreshold.integerValue) / 100) } ?? L(" da cota escolhida", " of the chosen quota"))
    }
    @objc private func changed() { dailyInputValid = true; refreshAppearance(); onChange?() }
    func controlTextDidChange(_ notification: Notification) {
        if (notification.object as? NSTextField) === dailyAmount {
            if let amount = number(dailyAmount.stringValue), let allowance, allowance > 0,
               amount > 0, amount >= allowance / 100 - 0.0001, amount <= allowance + 0.01 {
                dailyInputValid = true; dailyThreshold.doubleValue = min(100, max(1, amount / allowance * 100))
            } else { dailyInputValid = false }
        }
        onChange?()
    }
}
