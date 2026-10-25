import Foundation
import UserNotifications

@MainActor
final class BudgetNotifications: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private let ledgerURL: URL
    private var delivered: [String: Date] = [:]
    private var pending = Set<String>()
    private var checking = false
    private var policyGeneration = 0
    var onStatus: ((String) -> Void)?

    init(folder: URL) {
        ledgerURL = folder.appendingPathComponent("alert-history.json")
        super.init()
        if let data = try? Data(contentsOf: ledgerURL), let saved = try? JSONDecoder().decode([String: Date].self, from: data) { delivered = saved }
        delivered = delivered.filter { Date().timeIntervalSince($0.value) < 62 * 86400 }
        center.delegate = self
    }
    func requestPermissionIfNeeded(preferences: AppPreferences) {
        policyGeneration += 1
        let anyEnabled = preferences.notifyCycle || preferences.notifyDaily || preferences.notifyRenewal
        let anySound = preferences.alertSound
        if !anyEnabled { center.removePendingNotificationRequests(withIdentifiers: Array(pending)) }
        guard anyEnabled else { onStatus?(L("Avisos desligados.", "Alerts off.")); return }
        center.requestAuthorization(options: anySound ? [.alert, .sound] : [.alert]) { [weak self] allowed, _ in
            Task { @MainActor in self?.onStatus?(allowed ? L("Avisos ativados no macOS.", "Alerts enabled in macOS.") : L("Avisos bloqueados no macOS. Habilite-os em Ajustes do Sistema → Notificações.", "Alerts blocked in macOS. Enable them in System Settings → Notifications.")) }
        }
    }
    func resetAccount() {
        policyGeneration += 1; pending.removeAll(); delivered.removeAll(); checking = false
        center.removeAllPendingNotificationRequests(); center.removeAllDeliveredNotifications()
    }
    func readPermission() {
        center.getNotificationSettings { [weak self] settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                switch status {
                case .authorized, .provisional: self?.onStatus?(L("Permissão do macOS disponível; os avisos seguem suas escolhas.", "macOS permission granted; alerts follow your choices."))
                case .denied: self?.onStatus?(L("Notificações bloqueadas no macOS. Ative-as nos Ajustes do Sistema.", "Notifications blocked in macOS. Turn them on in System Settings."))
                default: self?.onStatus?(L("A permissão do macOS será solicitada somente se você ativar um aviso e salvar.", "macOS asks for permission only if you turn on an alert and save."))
                }
            }
        }
    }
    func evaluate(_ assessment: BudgetAssessment?, preferences: AppPreferences, quotaFresh: Bool) {
        guard quotaFresh, let assessment, !checking, preferences.notifyCycle || preferences.notifyDaily else { return }
        let alerts = BudgetAlerts.candidates(assessment: assessment, preferences: preferences, delivered: Set(delivered.keys).union(pending))
        guard !alerts.isEmpty else { return }
        checking = true
        deliver(alerts, sound: preferences.alertSound, releasesCheck: true)
    }

    // Renewals reuse the budget ledger, so each renewal is announced once across launches.
    func announceRenewals(_ events: [RenewalEvent], preferences: AppPreferences) {
        guard preferences.notifyRenewal, !events.isEmpty else { return }
        let alerts = events.map { BudgetAlert(id: $0.id, kind: .renewal, title: $0.title, body: $0.body) }
            .filter { !pending.contains($0.id) && delivered[$0.id] == nil }
        guard !alerts.isEmpty else { return }
        deliver(alerts, sound: preferences.alertSound, releasesCheck: false)
    }

    private func deliver(_ alerts: [BudgetAlert], sound: Bool, releasesCheck: Bool) {
        let generation = policyGeneration
        center.getNotificationSettings { [weak self] settings in
            let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            Task { @MainActor in
                guard let self else { return }
                if releasesCheck { self.checking = false }
                guard generation == self.policyGeneration else { return }
                guard authorized else { return }
                for alert in alerts where !self.pending.contains(alert.id) && self.delivered[alert.id] == nil {
                    self.pending.insert(alert.id)
                    let content = UNMutableNotificationContent(); content.title = alert.title; content.body = alert.body
                    if sound { content.sound = .default }
                    let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: nil)
                    guard generation == self.policyGeneration else { self.pending.remove(alert.id); return }
                    do {
                        try await self.center.add(request)
                        guard generation == self.policyGeneration else {
                            self.center.removePendingNotificationRequests(withIdentifiers: [alert.id])
                            self.center.removeDeliveredNotifications(withIdentifiers: [alert.id]); self.pending.remove(alert.id); continue
                        }
                        self.pending.remove(alert.id); self.delivered[alert.id] = Date()
                        if let data = try? JSONEncoder().encode(self.delivered) { try? data.write(to: self.ledgerURL, options: .atomic) }
                    } catch {
                        self.pending.remove(alert.id)
                        self.onStatus?(L("O macOS não conseguiu apresentar o aviso. Verifique as permissões.", "macOS could not show the alert. Check the permissions."))
                    }
                }
            }
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                           withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
