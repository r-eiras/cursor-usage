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
    // A click on any notice, routed to what it is about: an update installs, a new model opens its settings, others open the card.
    var onOpen: ((NotificationRoute) -> Void)?
    nonisolated static let updateCategory = NotificationRoute.updateCategory, installAction = NotificationRoute.installAction
    nonisolated static let newModelCategory = NotificationRoute.newModelCategory, monitorAction = NotificationRoute.monitorAction

    init(folder: URL) {
        ledgerURL = folder.appendingPathComponent("alert-history.json")
        super.init()
        if let data = try? Data(contentsOf: ledgerURL), let saved = try? JSONDecoder().decode([String: Date].self, from: data) { delivered = saved }
        // Weekend notices are said once for good, so they outlive the 62 days other notices are remembered.
        delivered = delivered.filter { $0.key.hasPrefix(WeekendNotices.prefix) || Date().timeIntervalSince($0.value) < 62 * 86400 }
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.updateCategory, actions: [UNNotificationAction(identifier: Self.installAction, title: L("Atualizar agora", "Update now"), options: [])], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.newModelCategory, actions: [UNNotificationAction(identifier: Self.monitorAction, title: L("Monitorar este modelo", "Monitor this model"), options: [.foreground])], intentIdentifiers: [])])
    }
    var announcedIDs: Set<String> { Set(delivered.keys).union(pending) }
    func requestPermissionIfNeeded(preferences: AppPreferences) {
        policyGeneration += 1
        let anyEnabled = preferences.notifyCycle || preferences.notifyDaily || preferences.notifyRenewal || preferences.notifyNewModel || preferences.notifyModelRate || !preferences.monitoredModels.isEmpty
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
        Task { @MainActor in
            let settings = await self.center.notificationSettings()
            self.onStatus?(NotificationAdvice.message(authorization: settings.authorizationStatus, style: settings.alertStyle))
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

    // Update notices need no alert turned on; the first one asks macOS for permission once.
    func announceUpdate(version: String) {
        let id = "update-\(version)"
        guard !pending.contains(id), delivered[id] == nil else { return }
        pending.insert(id)
        Task { @MainActor in
            defer { self.pending.remove(id) }
            var status = await self.center.notificationSettings().authorizationStatus
            if status == .notDetermined { status = ((try? await self.center.requestAuthorization(options: [.alert])) ?? false) ? .authorized : .denied }
            guard status == .authorized || status == .provisional else { return }
            let content = UNMutableNotificationContent(); content.categoryIdentifier = Self.updateCategory; content.userInfo = ["version": version]; content.threadIdentifier = "update"
            content.title = L("Cursor Usage \(version) disponível", "Cursor Usage \(version) is available")
            content.body = L("Clique para atualizar. O app reabre sozinho em alguns segundos.", "Click to update. The app reopens by itself in a few seconds.")
            do { try await self.center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) } catch { return }
            self.delivered[id] = Date()
            if let data = try? JSONEncoder().encode(self.delivered) { try? data.write(to: self.ledgerURL, options: .atomic) }
        }
    }

    // Model alerts start on without any setup, so like update notices they ask macOS once when the first one is due.
    func announceModels(_ alerts: [BudgetAlert], sound: Bool) { announceUnasked(alerts, sound: sound, kind: "models") }
    // Weekend notices need no setup either; a click opens the card's goal.
    func announceWeekend(_ alerts: [BudgetAlert], sound: Bool) { announceUnasked(alerts, sound: sound, kind: "goal") }
    private func announceUnasked(_ alerts: [BudgetAlert], sound: Bool, kind: String) {
        let due = alerts.filter { !pending.contains($0.id) && delivered[$0.id] == nil }
        guard !due.isEmpty else { return }
        due.forEach { pending.insert($0.id) }
        Task { @MainActor in
            defer { due.forEach { self.pending.remove($0.id) } }
            var status = await self.center.notificationSettings().authorizationStatus
            if status == .notDetermined { status = ((try? await self.center.requestAuthorization(options: sound ? [.alert, .sound] : [.alert])) ?? false) ? .authorized : .denied }
            guard status == .authorized || status == .provisional else { return }
            for alert in due {
                let content = UNMutableNotificationContent(); content.title = alert.title; content.body = alert.body
                if sound { content.sound = .default }
                content.threadIdentifier = kind; content.userInfo = ["kind": kind]
                if alert.kind == .newModel { content.categoryIdentifier = Self.newModelCategory; content.userInfo = ["kind": "models", "model": String(alert.id.dropFirst("model-new:".count))] }
                do { try await self.center.add(UNNotificationRequest(identifier: alert.id, content: content, trigger: nil)) } catch { continue }
                self.delivered[alert.id] = Date()
            }
            if let data = try? JSONEncoder().encode(self.delivered) { try? data.write(to: self.ledgerURL, options: .atomic) }
        }
    }

    // After an update, notices about the version now installed, or an older one, are stale.
    func clearUpdateNotices(installed: String) {
        Task { @MainActor in
            let delivered = AppUpdater.staleUpdateNotices(await self.center.deliveredNotifications().map(\.request.identifier), installed: installed)
            if !delivered.isEmpty { self.center.removeDeliveredNotifications(withIdentifiers: delivered) }
            let pending = AppUpdater.staleUpdateNotices(await self.center.pendingNotificationRequests().map(\.identifier), installed: installed)
            if !pending.isEmpty { self.center.removePendingNotificationRequests(withIdentifiers: pending) }
        }
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
                    content.threadIdentifier = "goal"; content.userInfo = ["kind": "goal"]
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
        // `.list` keeps the notice in Notification Center; without it a notice that arrives while the app is active is gone with its banner.
        completionHandler([.banner, .list, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Clicking the body is the natural gesture, and action buttons only show on hover; both lead to the same place.
        let route = NotificationRoute.of(category: response.notification.request.content.categoryIdentifier, userInfo: response.notification.request.content.userInfo)
        Task { @MainActor in self.onOpen?(route); completionHandler() }
    }
}
