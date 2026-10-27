import AppKit
import WebKit

@MainActor
final class CursorUsageApp: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate, NSPopoverDelegate, NSWindowDelegate {
    private var status = NSStatusBar.system.statusItem(withLength: 24)
    private var lastPlacementRecovery = Date.distantPast
    private var placementRecoveries = 0
    private let popover = NSPopover()
    private let card = QuotaCard(frame: NSRect(origin: .zero, size: QuotaCard.size))
    private let exporter = UsageExporter()
    private var popoverDismissal: PopoverDismissal!
    private var hoverTimer: Timer?
    private var hoverState = HoverDismissalState()
    private var hoveredByPointer = false
    private var timer: Timer?
    private var window: NSWindow!
    private var webView: WKWebView?
    private let accountStorage = AccountSessionStorage(folder: AppFolder.url)
    private let browserSessions = BrowserSessionStore(folder: AppFolder.url)
    private var browserSignIn: Task<Void, Never>?
    private var browserButton: NSButton?
    private var awaitingBrowserSession = false
    private var lastRenewalCheck = Date.distantPast
    private var availableUpdate: String?
    private var nextUpdateCheck = Date().addingTimeInterval(60)
    private var installingUpdate = false
    // Models this account has used, so a first use can be told apart; nil until the first import.
    private var knownModels: Set<String>?
    private var lastModelEvaluation: Date?
    private var isSignedOut = false
    private var signingOut = false
    private var loginPaused = false
    private var preferences = AppPreferences()
    private var preferencesPanel: PreferencesPanel?
    private var checkingForUpdates = false
    private let loginItem = LoginItemManager()
    private var notifications: BudgetNotifications!
    private var notificationStatus = ""
    private var history: [UsageSnapshot] = []
    private var dataset: UsageDataset?
    private var selection = PeriodSelection()
    private var message = ""
    private var analyticsMessage = ""
    private var lastRefresh = Date.distantPast
    private var lastRead = Date.distantPast
    private var sourceLoadedAt = Date.distantPast
    private var lastCSVAttempt = Date.distantPast
    private var exportInFlight = false
    private var requestedCoverage: DateInterval?
    private var refreshGeneration = 0
    private var connectionFailed = false
    private var usageRedirectAttempted = false
    private var pageIdle = false
    private var historySettled = false
    private var extractionDiagnostic: [String: Any] = [:]
    private var lastDiagnostic: Data?
    private static let blankPage = URL(string: "about:blank")!
    private let dashboard = URL(string: "https://cursor.com/dashboard/usage")!
    private let storage = AppFolder.url.appendingPathComponent("history.json")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let folder = storage.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
        isSignedOut = accountStorage.isSignedOut
        if !isSignedOut, let data = try? Data(contentsOf: storage), let saved = try? JSONDecoder().decode([UsageSnapshot].self, from: data) { history = saved }
        if !isSignedOut, let data = try? Data(contentsOf: folder.appendingPathComponent("events.json")) { dataset = try? JSONDecoder().decode(UsageDataset.self, from: data) }
        if !isSignedOut, let data = try? Data(contentsOf: folder.appendingPathComponent("models-seen.json")) { knownModels = try? JSONDecoder().decode(Set<String>.self, from: data) }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("period.json")), let saved = try? JSONDecoder().decode(PeriodSelection.self, from: data) { selection = saved }
        if let data = try? Data(contentsOf: folder.appendingPathComponent("preferences.json")), let saved = try? JSONDecoder().decode(AppPreferences.self, from: data) { preferences = saved }
        AppLanguage.current = preferences.language; card.localize()
        message = isSignedOut ? L("Conta desconectada", "Account disconnected") : QuotaMessages.waiting("Cursor"); analyticsMessage = isSignedOut ? L("Conecte sua conta para acompanhar o consumo.", "Connect your account to track usage.") : L("Carregando histórico…", "Loading history…")
        notifications = BudgetNotifications(folder: folder)
        notifications.onStatus = { [weak self] value in self?.notificationStatus = value; self?.preferencesPanel?.setStatus(value) }
        notifications.onUpdateRequested = { [weak self] install in if install { self?.installAvailableUpdate() } else { self?.checkForUpdates() } }
        notifications.onMonitorModel = { [weak self] model in self?.showPreferences(); self?.preferencesPanel?.monitor(model) }
        // Leftovers of the update that installed this version: its download folder and its notice.
        try? FileManager.default.removeItem(at: AppUpdater.stagingFolder()); notifications.clearUpdateNotices(installed: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        let controller = NSViewController(); controller.view = card
        popover.contentViewController = controller; popover.contentSize = QuotaCard.size
        popover.behavior = .transient; popover.delegate = self; popover.animates = false; popover.appearance = NSAppearance(named: .darkAqua)
        configureStatusItem()
        popoverDismissal = PopoverDismissal(isInside: { [weak self] candidate in
            guard let self, let candidate else { return false }
            return candidate === self.popover.contentViewController?.view.window || candidate === self.status.button?.window
        }, dismiss: { [weak self] in self?.closePopovers() })
        card.onConnect = { [weak self] in self?.showDashboard() }; card.onRefresh = { [weak self] in self?.refresh() }
        card.onQuit = { NSApp.terminate(nil) }; card.onPeriod = { [weak self] in self?.selectPeriod($0) }
        card.onPreferences = { [weak self] in self?.showPreferences() }
        exporter.onDataset = { [weak self] data in
            guard let self else { return }
            self.dataset = data; self.exportInFlight = false; self.historySettled = true
            self.analyticsMessage = L("Histórico sincronizado · \(data.events.count) requisições", "History synced · \(data.events.count) requests")
            let file = folder.appendingPathComponent("events.json")
            if let encoded = try? JSONEncoder().encode(data) { try? encoded.write(to: file, options: .atomic); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
            self.render()
        }
        exporter.onFailure = { [weak self] value in self?.exportInFlight = false; self?.historySettled = true; self?.analyticsMessage = value; self?.render() }
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("Cursor Usage — entre no painel oficial do Cursor", "Cursor Usage — sign in to the official Cursor dashboard")
        window.isReleasedWhenClosed = false; window.delegate = self; window.center(); addBrowserSignInAccessory()
        render(); refresh()
        if CommandLine.arguments.contains("--preferences") { showPreferences() }
        else if !isSignedOut && (history.isEmpty || CommandLine.arguments.contains("--connect")) { showDashboard() }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    private func configureStatusItem() {
        status.autosaveName = StatusItemPlacement.autosaveName
        status.button?.target = self; status.button?.action = #selector(togglePopover)
        status.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        if let button = status.button { button.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)) }
    }
    private func recoverStatusItemIfNeeded() {
        guard let host = status.button?.window,
              StatusItemPlacement.needsRecovery(frame: host.frame, rightArea: host.screen?.auxiliaryTopRightArea),
              Date().timeIntervalSince(lastPlacementRecovery) > 30 else { return }
        lastPlacementRecovery = Date(); placementRecoveries += 1
        closePopovers()
        // Removing an item saves its old position, so reset after removing it.
        NSStatusBar.system.removeStatusItem(status)
        StatusItemPlacement.resetPosition()
        status = NSStatusBar.system.statusItem(withLength: 24)
        configureStatusItem()
    }
    private func tick() {
        if !isSignedOut && !loginPaused && Date().timeIntervalSince(lastRefresh) >= preferences.syncInterval.seconds && (!window.isVisible || webView?.url?.path == dashboard.path) { refresh() }
        if Date().timeIntervalSince(lastRenewalCheck) >= 3600 { lastRenewalCheck = Date(); renewBrowserSessionIfNeeded() }
        if Date() >= nextUpdateCheck { nextUpdateCheck = Date().addingTimeInterval(86400); checkForUpdatesQuietly() }
        readUsage(); releasePageIfSynced(); evaluateModelAlerts(); render()
    }
    @objc private func togglePopover() {
        guard let button = status.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            closePopovers()
            let menu = StatusMenu.make(target: self, settings: #selector(showPreferences), about: #selector(showAbout), updates: #selector(checkForUpdates), issues: #selector(reportIssue), logout: #selector(disconnectAccount), canDisconnect: !isSignedOut && !signingOut, quit: #selector(quitFromMenu),
                                     update: availableUpdate.map { (L("Atualizar para \($0)…", "Update to \($0)…"), #selector(installAvailableUpdate)) })
            NSMenu.popUpContextMenu(menu, with: event, for: button)
            return
        }
        if popover.isShown && hoveredByPointer { return }
        if popover.isShown { popover.performClose(nil) }
        else { preferencesPanel?.suspendForMenuBar(); render(forceCard: true); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }
    @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
        guard preferences.menuOpenBehavior == .hoverAndClick, !window.isVisible, !popover.isShown else { return }
        hoveredByPointer = true; togglePopover()
    }
    @objc(mouseExited:) func mouseExited(with event: NSEvent) {}
    private func startHoverDismissal() {
        hoverTimer?.invalidate(); hoverState.reset()
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.checkHoverPosition() } }
        hoverTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    private func checkHoverPosition() {
        guard popover.isShown else { hoverTimer?.invalidate(); hoverTimer = nil; return }
        let point = NSEvent.mouseLocation
        let onIcon: Bool
        if let button = status.button, let host = button.window { onIcon = host.convertToScreen(button.convert(button.bounds, to: nil)).insetBy(dx: -2, dy: -2).contains(point) }
        else { onIcon = false }
        let onPanel = popover.contentViewController?.view.window?.frame.insetBy(dx: -2, dy: -2).contains(point) ?? false
        if hoverState.shouldDismiss(pointerInside: onIcon || onPanel) { closePopovers() }
    }
    private func closePopovers() {
        hoverTimer?.invalidate(); hoverTimer = nil; hoveredByPointer = false; card.hideModelDetail(); popover.close(); popoverDismissal.stop()
    }
    func popoverWillShow(_ notification: Notification) {
        if !hoveredByPointer { NSApp.activate(ignoringOtherApps: true) }; popoverDismissal.start(); startHoverDismissal()
    }
    func popoverDidShow(_ notification: Notification) {
        if let host = popover.contentViewController?.view.window {
            host.collectionBehavior.subtract([.moveToActiveSpace, .canJoinAllSpaces]); if !hoveredByPointer { host.makeKey() }
        }
    }
    func popoverDidClose(_ notification: Notification) { card.hideModelDetail(); hoveredByPointer = false; popoverDismissal.stop(); hoverTimer?.invalidate(); hoverTimer = nil }
    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }
    private func ensureWebView() -> WKWebView {
        if let webView { return webView }
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self; view.uiDelegate = self; webView = view; exporter.webView = view; window.contentView = view
        return view
    }
    private func releaseBrowser() {
        webView?.stopLoading(); webView?.navigationDelegate = nil; webView?.uiDelegate = nil
        window.contentView = nil; exporter.webView = nil; webView = nil; pageIdle = true
    }
    @objc private func refresh() {
        guard !isSignedOut, !signingOut else { render(); return }
        if loginPaused { showDashboard(); return }
        exporter.cancelAll(); exportInFlight = false; usageRedirectAttempted = false; pageIdle = false; historySettled = false
        refreshGeneration += 1; lastRefresh = Date(); lastCSVAttempt = .distantPast
        message = QuotaMessages.checking("Cursor"); analyticsMessage = L("Sincronizando histórico…", "Syncing history…")
        ensureWebView().load(URLRequest(url: requestedDashboard())); render()
    }
    private func releasePageIfSynced() {
        guard !pageIdle, !window.isVisible, lastRead >= lastRefresh, !exporter.isBusy, !exportInFlight,
              historySettled || Date().timeIntervalSince(lastRefresh) > 90 else { return }
        refreshGeneration += 1
        releaseBrowser()
    }

    @objc private func showDashboard() {
        closePopovers()
        guard !signingOut else { return }
        loginPaused = false
        if isSignedOut {
            // A reconnect repeats cleanup in case the app quit during a prior logout.
            signingOut = true
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
                Task { @MainActor in
                    guard let self else { return }; self.signingOut = false
                    do { try self.accountStorage.reconnect(); self.isSignedOut = false; self.showDashboard() }
                    catch { self.preferencesPanel?.setStatus(L("Não foi possível iniciar a conexão.", "Could not start the connection.")) }
                }
            }
            return
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if pageIdle || connectionFailed || webView == nil { refresh() }
    }

    // The embedded page cannot show a passkey from Cursor's identity providers; the default browser can.
    private func addBrowserSignInAccessory() {
        browserButton = BrowserSignInButton.install(in: window, target: self, action: #selector(toggleBrowserSignIn)); updateBrowserButton()
    }
    private func updateBrowserButton() { if let browserButton { BrowserSignInButton.update(browserButton, waiting: browserSignIn != nil) } }
    @objc private func toggleBrowserSignIn() {
        if let task = browserSignIn { task.cancel(); browserSignIn = nil; updateBrowserButton(); return }
        message = L("Conclua o login no navegador. O app atualiza sozinho.", "Finish signing in in your browser. The app updates by itself."); render()
        let flow = BrowserSignIn(open: { url in DispatchQueue.main.async { NSWorkspace.shared.open(url) } })
        browserSignIn = Task { [weak self] in
            do {
                let session = try await flow.run()
                guard let self, !Task.isCancelled else { return }
                self.browserSignIn = nil; self.updateBrowserButton(); self.adopt(session)
            } catch {
                guard let self, !(error is CancellationError) else { return }
                self.browserSignIn = nil; self.updateBrowserButton()
                switch error as? BrowserSignInError {
                case .timedOut?: self.reportBrowserFailure(L("O tempo para concluir o login no navegador acabou. Tente de novo.", "The time to finish signing in in the browser ran out. Try again."))
                case .rejected?: self.reportBrowserFailure(L("O Cursor respondeu de um jeito que o app não reconhece. Entre nesta janela, por exemplo com e-mail e código.", "Cursor answered in a way the app does not recognize. Sign in in this window, for example with email and a code."))
                default: self.reportBrowserFailure(L("Não foi possível falar com o Cursor. Verifique a conexão e tente de novo.", "Could not reach Cursor. Check your connection and try again."))
                }
            }
        }
        updateBrowserButton()
    }
    // The browser session becomes the dashboard's own cookie, so reading the quota and history stays unchanged.
    private func adopt(_ session: BrowserSession) {
        guard let cookie = session.cookie() else { browserSessionRejected(); return }
        try? browserSessions.save(session)
        WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isSignedOut { try? self.accountStorage.reconnect(); self.isSignedOut = false }
                self.awaitingBrowserSession = true; self.loginPaused = false; self.connectionFailed = false
                self.message = L("Login no navegador concluído. Buscando sua cota…", "Browser sign-in complete. Fetching your quota…")
                self.refresh()
            }
        }
    }
    private func browserSessionRejected() {
        awaitingBrowserSession = false; browserSessions.delete()
        reportBrowserFailure(L("O Cursor não aceitou o login feito no navegador. Entre nesta janela, por exemplo com e-mail e código.", "Cursor did not accept the browser sign-in. Sign in in this window, for example with email and a code."))
    }
    private func reportBrowserFailure(_ text: String) {
        let alert = NSAlert(); alert.icon = CursorMark.appImage(size: 64, template: false)
        alert.messageText = L("Login pelo navegador externo não concluído", "External browser sign-in not completed"); alert.informativeText = text
        if window.isVisible { alert.beginSheetModal(for: window) } else { NSApp.activate(ignoringOtherApps: true); alert.runModal() }
    }
    // Browser sign-ins last about two months; renewing a day ahead keeps the dashboard cookie from lapsing.
    private func renewBrowserSessionIfNeeded() {
        guard !isSignedOut, let session = browserSessions.load(), session.needsRenewal() else { return }
        let flow = BrowserSignIn(open: { _ in })
        Task { [weak self] in
            let outcome = await flow.renew(session)
            guard let self, !self.isSignedOut else { return }
            switch outcome {
            case .renewed(let renewed):
                try? self.browserSessions.save(renewed)
                if let cookie = renewed.cookie() { await WKWebsiteDataStore.default().httpCookieStore.setCookie(cookie) }
            case .signedOut: self.browserSessions.delete()
            case .failed: break
            }
        }
    }

    private func pauseLogin() {
        loginPaused = true; refreshGeneration += 1; exporter.cancelAll(); exportInFlight = false; releaseBrowser()
        message = L("Conecte sua conta para atualizar a cota.", "Connect your account to update the quota."); render()
    }
    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) === window, let webView,
              history.isEmpty || connectionFailed || DashboardLocation.destination(for: webView.url) == .signIn else { return }
        pauseLogin()
    }
    private func readUsage() {
        guard !isSignedOut, !pageIdle, let webView, !webView.isLoading else { return }
        let destination = DashboardLocation.destination(for: webView.url)
        if destination == .dashboard {
            if !usageRedirectAttempted {
                usageRedirectAttempted = true
                message = L("Conta conectada. Buscando sua cota…", "Account connected. Fetching your quota…")
                webView.load(URLRequest(url: requestedDashboard()))
            } else {
                message = L("O Cursor voltou à página inicial. Tente atualizar.", "Cursor went back to its home page. Try refreshing.")
            }
            render()
            return
        }
        guard !connectionFailed, destination == .usage else {
            message = QuotaMessages.waiting("Cursor")
            render()
            return
        }
        // Monthly quota remains the provider balance; event metrics come from its own CSV export.
        let generation = refreshGeneration
        webView.evaluateJavaScript(QuotaExtraction.script) { [weak self] result, error in
            guard let self, generation == self.refreshGeneration else { return }
            let extraction = result as? [String: Any] ?? [:]
            self.extractionDiagnostic = extraction.filter { $0.key != "summary" }
            if let error { self.extractionDiagnostic["error"] = error.localizedDescription }
            guard error == nil, let text = extraction["summary"] as? String,
                  let reading = try? UsageParser.parse(text) else {
                self.message = QuotaMessages.unavailable("Cursor")
                self.lastRead = .distantPast
                self.render()
                return
            }
            let firstConnection = self.history.isEmpty || self.awaitingBrowserSession; self.awaitingBrowserSession = false
            self.lastRead = self.sourceLoadedAt
            self.message = QuotaMessages.synced("Cursor")
            // Monthly cycle: a new reset a month ahead after the previous one passed is a renewal.
            let renewal = RenewalDetector.event( previousReset: self.history.last?.resetDate, currentReset: reading.resetDate, observedAt: Date())
            self.notifications.announceRenewals(renewal.map { [$0] } ?? [], preferences: self.preferences)
            if self.history.last.map({ Date().timeIntervalSince($0.observedAt) >= 300 ||
                $0.spentCents != reading.spentCents || $0.limitCents != reading.limitCents ||
                $0.resetDate != reading.resetDate }) ?? true {
                self.history.append(reading)
                self.history = self.history.filter { Date().timeIntervalSince($0.observedAt) < 40 * 86400 }
                self.save()
            }
            self.maybeExport()
            self.render()
            if firstConnection && self.window.isVisible {
                self.window.orderOut(nil)
                if let button = self.status.button {
                    self.render(forceCard: true)
                    self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: storage.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(history)
            try data.write(to: storage, options: [.atomic, .completeFileProtectionUnlessOpen])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storage.path)
        } catch {
            message = L("Leitura atual OK; falha ao salvar histórico", "Current reading OK; could not save history")
        }
    }

    private func requestedDashboard() -> URL {
        let now = Date(), calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: now)!
        let selected = selection.interval(now: now, calendar: calendar)
        let recent = PeriodSelection(preset: .last7).interval(now: now, calendar: calendar)!
        let beginning = [month.start, selected?.start ?? month.start, recent.start].min()!
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let from = utc.startOfDay(for: beginning)
        let end = utc.date(byAdding: .day, value: 1, to: utc.startOfDay(for: now))!
        let coverage = DateInterval(start: from, end: end)
        requestedCoverage = coverage; exporter.prepare(coverage: coverage)
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = utc.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        var parts = URLComponents(url: dashboard, resolvingAgainstBaseURL: false)!
        parts.queryItems = [URLQueryItem(name: "from", value: formatter.string(from: from)), URLQueryItem(name: "to", value: formatter.string(from: now))]
        return parts.url!
    }

    private func maybeExport() {
        guard !isSignedOut, let webView else { return }
        let generation = refreshGeneration
        if exporter.isBusy { return }
        if exportInFlight {
            if Date().timeIntervalSince(lastCSVAttempt) > 45 {
                exportInFlight = false; historySettled = true; analyticsMessage = L("Histórico indisponível. Tente atualizar.", "History unavailable. Try refreshing."); return
            }
            webView.evaluateJavaScript(UsageExporter.linkScript) { [weak self] value, _ in
                if let self, generation == self.refreshGeneration, let raw = value as? String, let url = URL(string: raw) { _ = self.exporter.capture(URLRequest(url: url)) }
            }
            return
        }
        guard Date().timeIntervalSince(lastCSVAttempt) >= preferences.syncInterval.seconds, requestedCoverage != nil else { return }
        webView.evaluateJavaScript(UsageExporter.triggerScript) { [weak self] value, _ in
            guard let self, generation == self.refreshGeneration else { return }
            if value as? Bool == true {
                self.lastCSVAttempt = Date(); self.exportInFlight = true
                self.analyticsMessage = L("Baixando histórico do Cursor…", "Downloading Cursor history…")
            }
        }
    }

    private func savePeriod() {
        if let data = try? JSONEncoder().encode(selection) { try? data.write(to: storage.deletingLastPathComponent().appendingPathComponent("period.json"), options: .atomic) }
    }

    private func selectPeriod(_ period: UsagePeriod) {
        selection.preset = period; savePeriod(); render(); refresh()
    }

    private func render(forceCard: Bool = false) {
        preferencesPanel?.updateReadings()
        let latest = history.last, now = Date()
        let stale = latest.map { now.timeIntervalSince(lastRead) > preferences.freshnessInterval || $0.resetDate <= now } ?? false
        let budget = latest.flatMap { BudgetEngine.assess(quota: $0, dataset: dataset, preferences: preferences, now: now) }
        let presentation = MenuBarPresentation.make(preferences: preferences, quota: latest, dataset: dataset, now: now, assessment: budget)
        recoverStatusItemIfNeeded()
        if !status.isVisible { status.isVisible = true }
        if let button = status.button {
            CursorMark.configure(button, title: presentation.title, showsIcon: preferences.showIcon || preferences.menuBarDensity == .iconsOnly, style: preferences.menuIconStyle)
            let width = ceil(button.attributedTitle.size().width) + (button.image == nil ? 14 : 34)
            if status.length != max(24, width) { status.length = max(24, width) }
            button.toolTip = nil; button.setAccessibilityLabel(ProjectLinks.name)
        }
        if forceCard || popover.isShown {
            card.configure(preferences: preferences, budget: budget)
            card.update(snapshot: latest, dataset: dataset, selection: selection, stale: stale, message: message, analyticsMessage: analyticsMessage)
        }
        notifications.evaluate(budget, preferences: preferences, quotaFresh: !stale)
        let statusData: [String: Any] = ["version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development", "pid": ProcessInfo.processInfo.processIdentifier, "readings": history.count, "events": dataset?.events.count ?? 0, "message": message, "analytics": analyticsMessage, "loading": webView?.isLoading ?? false, "dashboardResident": webView != nil, "signedOut": isSignedOut, "loginPaused": loginPaused, "statusVisible": status.isVisible, "statusWindowVisible": status.button?.window?.isVisible ?? false, "placementRecoveries": placementRecoveries, "statusSafeArea": status.button?.window?.screen?.auxiliaryTopRightArea.map { NSStringFromRect($0) } ?? "", "statusFrame": status.button.map { NSStringFromRect($0.window?.frame ?? .zero) } ?? "", "preferencesVisible": preferencesPanel?.window?.isVisible ?? false, "pageIdle": pageIdle]
        if let data = try? JSONSerialization.data(withJSONObject: statusData, options: [.sortedKeys]), data != lastDiagnostic {
            lastDiagnostic = data; try? data.write(to: storage.deletingLastPathComponent().appendingPathComponent("status.json"), options: .atomic)
        }
    }
    @objc private func disconnectAccount() {
        guard !signingOut else { return }
        do { try accountStorage.disconnect() } catch {
            let alert = NSAlert(); alert.messageText = L("Não foi possível desconectar", "Could not disconnect")
            alert.informativeText = L("O histórico foi preservado. Tente novamente.", "Your history was preserved. Please try again."); alert.runModal(); return
        }
        browserSignIn?.cancel(); browserSignIn = nil; browserSessions.delete(); awaitingBrowserSession = false; updateBrowserButton()
        isSignedOut = true; signingOut = true; refreshGeneration += 1
        exporter.cancelAll(); exportInFlight = false; historySettled = true; closePopovers(); window.orderOut(nil); releaseBrowser()
        history.removeAll(); dataset = nil; lastRead = .distantPast; notifications.resetAccount(); knownModels = nil; lastModelEvaluation = nil
        message = L("Conta desconectada", "Account disconnected"); analyticsMessage = L("Conecte sua conta para acompanhar o consumo.", "Connect your account to track usage.")
        render(forceCard: true)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { [weak self] in
            Task { @MainActor in self?.signingOut = false; self?.render(forceCard: true) }
        }
    }
    @objc private func quitFromMenu() { NSApp.terminate(nil) }
    @objc private func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "development"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSMutableAttributedString(string: L("Consumo do Cursor na barra de menus.\nProjeto independente, sem vínculo com a Anysphere.\n\n", "Cursor usage in the menu bar.\nIndependent project, not affiliated with Anysphere.\n\n"))
        for (title, url) in [(L("Criado por \(ProjectLinks.author)", "Created by \(ProjectLinks.author)"), ProjectLinks.authorProfile), (L("Código no GitHub", "Source on GitHub"), ProjectLinks.repository), (L("Novidades das versões", "Release notes"), ProjectLinks.releases), (L("Reportar problema", "Report an issue"), ProjectLinks.issues), (L("Licença MIT", "MIT license"), ProjectLinks.license)] {
            credits.append(NSAttributedString(string: title, attributes: [.link: url]))
            credits.append(NSAttributedString(string: "\n"))
        }
        credits.addAttribute(.font, value: NSFont.systemFont(ofSize: 11), range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: ProjectLinks.name, .applicationVersion: version, .version: build,
            .applicationIcon: CursorMark.appImage(size: 96, template: false), .credits: credits
        ])
    }
    @objc private func reportIssue() { NSWorkspace.shared.open(ProjectLinks.issues) }
    @objc private func checkForUpdates() {
        guard !checkingForUpdates else { return }
        checkingForUpdates = true; preferencesPanel?.setUpdateChecking(true)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        Task { [weak self] in
            let result = await ReleaseChecker.check(installedVersion: version)
            guard let self else { return }
            self.checkingForUpdates = false; self.preferencesPanel?.setUpdateChecking(false)
            let alert = NSAlert(); alert.icon = CursorMark.appImage(size: 64, template: false)
            var releaseURL = ProjectLinks.releases
            var hasUpdate = false
            switch result {
            case .upToDate:
                alert.messageText = L("Você está atualizado", "You are up to date")
                alert.informativeText = L("Cursor Usage \(version). Nenhuma versão mais recente foi publicada.", "Cursor Usage \(version). No newer version has been published.")
            case .available(let latest, let url):
                hasUpdate = true; releaseURL = url; self.availableUpdate = latest
                alert.messageText = L("Nova versão disponível", "A new version is available")
                alert.informativeText = L("Cursor Usage \(latest) está disponível. Você está usando \(version). Atualizar baixa a versão nova, confere a integridade e reabre o app.", "Cursor Usage \(latest) is available. You are using \(version). Updating downloads the new version, verifies it and reopens the app.")
            case .noRelease:
                alert.messageText = L("Nenhuma versão publicada", "No published releases")
                alert.informativeText = L("O repositório ainda não tem uma versão pública disponível.", "The repository does not have a public release yet.")
            case .rateLimited:
                alert.messageText = L("O GitHub limitou temporariamente as consultas", "GitHub temporarily limited requests")
                alert.informativeText = L("Tente novamente mais tarde ou confira as versões no GitHub.", "Try again later or view releases on GitHub.")
            case .failed:
                alert.messageText = L("Não foi possível verificar atualizações", "Could not check for updates")
                alert.informativeText = L("Verifique sua conexão e tente novamente. Você também pode consultar as versões no GitHub.", "Check your connection and try again. You can also view releases on GitHub.")
            }
            alert.addButton(withTitle: hasUpdate ? L("Atualizar agora", "Update now") : L("Entendi", "OK"))
            alert.addButton(withTitle: hasUpdate ? L("Agora não", "Not now") : L("Ver versões", "View releases"))
            if hasUpdate { alert.addButton(withTitle: L("Ver novidades", "Release notes")) }
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            if hasUpdate, response == .alertFirstButtonReturn, let latest = self.availableUpdate { self.installUpdate(latest) }
            else if (hasUpdate && response == .alertThirdButtonReturn) || (!hasUpdate && response == .alertSecondButtonReturn) { NSWorkspace.shared.open(releaseURL) }
        }
    }
    private var cycleStart: Date? {
        history.last.flatMap { quota in BudgetEngine.assess(quota: quota, dataset: dataset, preferences: preferences, now: Date())?.cycle.start }
    }
    // Once per import, and again when settings change. First uses are remembered even with that alert off.
    private func evaluateModelAlerts(force: Bool = false) {
        guard !isSignedOut, let dataset, force || lastModelEvaluation != dataset.fetchedAt else { return }
        lastModelEvaluation = dataset.fetchedAt
        let result = ModelAlerts.evaluate(dataset: dataset, preferences: preferences, known: knownModels, cycleStart: cycleStart, now: Date(), delivered: notifications.announcedIDs)
        if result.known != knownModels {
            knownModels = result.known
            let file = AppFolder.url.appendingPathComponent("models-seen.json")
            if let data = try? JSONEncoder().encode(result.known) { try? data.write(to: file, options: .atomic); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
        }
        notifications.announceModels(result.alerts, sound: preferences.alertSound)
    }
    // Models of the current cycle for the settings picker, costliest first; "new" when first seen in the last three days.
    private func modelChoices() -> [ModelAlertControls.Choice] {
        guard let dataset else { return [] }
        let now = Date(), start = cycleStart ?? Calendar.current.dateInterval(of: .month, for: now)!.start, recent = now.addingTimeInterval(-3 * 86400)
        var spend: [String: Int64] = [:], first: [String: Date] = [:]
        for event in dataset.events {
            if event.date >= start { spend[event.model, default: 0] += event.costMicros }
            first[event.model] = min(first[event.model] ?? event.date, event.date)
        }
        return first.keys.map { ModelAlertControls.Choice(model: $0, cycleSpendMicros: spend[$0] ?? 0, isNew: dataset.coverageStart < recent && (first[$0] ?? now) >= recent) }
            .sorted { $0.cycleSpendMicros == $1.cycleSpendMicros ? $0.model < $1.model : $0.cycleSpendMicros > $1.cycleSpendMicros }
    }
    // A daily check: a new release is announced once and stays offered in the menu until installed.
    private func checkForUpdatesQuietly() {
        guard !checkingForUpdates, !installingUpdate else { return }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        Task { [weak self] in
            guard case .available(let latest, _) = await ReleaseChecker.check(installedVersion: version), let self else { return }
            self.availableUpdate = latest; self.notifications.announceUpdate(version: latest)
        }
    }
    @objc private func installAvailableUpdate() { if let availableUpdate { installUpdate(availableUpdate) } else { checkForUpdates() } }
    // Downloads and verifies the release, swaps the bundle and reopens the app; any failure keeps this version running.
    private func installUpdate(_ version: String) {
        guard !installingUpdate else { return }
        installingUpdate = true; preferencesPanel?.setUpdateChecking(true, installing: true)
        message = L("Atualizando para \(version)…", "Updating to \(version)…"); render()
        let installed = Bundle.main.bundleURL
        Task { [weak self] in
            var folder: URL?
            do {
                let workspace = try AppUpdater.makeStagingFolder()
                folder = workspace
                let staged = try await AppUpdater().prepare(AppUpdate(version: version), in: workspace)
                try AppUpdater.install(staged, over: installed)
                // Clean up now: terminating ends the process before any deferred cleanup would run.
                try? FileManager.default.removeItem(at: workspace)
                let command = AppUpdater.relaunchCommand(pid: ProcessInfo.processInfo.processIdentifier, app: installed)
                let helper = Process(); helper.executableURL = URL(fileURLWithPath: command[0]); helper.arguments = Array(command.dropFirst())
                try? helper.run()
                NSApp.terminate(nil)
            } catch {
                if let folder { try? FileManager.default.removeItem(at: folder) }
                guard let self else { return }
                self.installingUpdate = false; self.preferencesPanel?.setUpdateChecking(false)
                self.message = L("Atualização não concluída; esta versão continua funcionando.", "Update not completed; this version keeps working."); self.render()
                self.reportUpdateFailure(error as? AppUpdateError)
            }
        }
    }
    private func reportUpdateFailure(_ error: AppUpdateError?) {
        let alert = NSAlert(); alert.icon = CursorMark.appImage(size: 64, template: false)
        alert.messageText = L("Não foi possível atualizar", "Could not update")
        switch error {
        case .notWritable?: alert.informativeText = L("O app não tem permissão para se substituir neste local. Mova-o para Aplicativos ou instale pelo comando do README.", "The app cannot replace itself in this location. Move it to Applications or install with the command in the README.")
        case .checksum?, .bundle?: alert.informativeText = L("O download não passou na verificação e foi descartado. Nada foi alterado.", "The download failed verification and was discarded. Nothing was changed.")
        default: alert.informativeText = L("Verifique sua conexão e tente de novo. Esta versão continua funcionando.", "Check your connection and try again. This version keeps working.")
        }
        alert.addButton(withTitle: L("Entendi", "OK")); alert.addButton(withTitle: L("Ver versão no GitHub", "View release on GitHub"))
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(ProjectLinks.releases) }
    }
    @objc private func showPreferences() {
        closePopovers()
        if preferencesPanel == nil {
            let panel = PreferencesPanel()
            panel.startupState = { [weak self] in self?.loginItem.state ?? .unavailable }
            panel.onStartupChange = { [weak self] in try self?.loginItem.setEnabled($0) }
            panel.onStartupSettings = { LoginItemManager.openSettings() }
            panel.onModelChoices = { [weak self] in self?.modelChoices() ?? [] }
            panel.onConnect = { [weak self] in self?.showDashboard() }
            panel.onDisconnect = { [weak self] in self?.disconnectAccount() }
            panel.canDisconnect = { [weak self] in self.map { !$0.isSignedOut && !$0.signingOut } ?? false }
            panel.onReportIssue = { [weak self] in self?.reportIssue() }
            panel.onAbout = { [weak self] in self?.showAbout() }; panel.onCheckUpdates = { [weak self] in self?.checkForUpdates() }
            panel.onCursorAssessment = { [weak self] value in
                guard let self, let quota = self.history.last else { return nil }
                return BudgetEngine.assess(quota: quota, dataset: self.dataset, preferences: value, now: Date())
            }
            panel.onPreview = { [weak self] value in
                guard let self else { return "—" }
                return MenuBarPresentation.make(preferences: value, quota: self.history.last, dataset: self.dataset, now: Date()).title
            }
            panel.onSave = { [weak self] value in
                guard let self, let data = try? JSONEncoder().encode(value) else { return false }
                let file = self.storage.deletingLastPathComponent().appendingPathComponent("preferences.json")
                guard (try? data.write(to: file, options: .atomic)) != nil else { self.preferencesPanel?.setStatus(L("Não foi possível salvar.", "Could not save.")); return false }
                let changedLanguage = value.language != self.preferences.language
                self.preferences = value; AppLanguage.current = value.language; self.card.localize()
                if changedLanguage { DispatchQueue.main.async { [weak self] in self?.preferencesPanel = nil } }
                self.window.title = L("Cursor Usage — entre no painel oficial do Cursor", "Cursor Usage — sign in to the official Cursor dashboard")
                self.updateBrowserButton(); self.notifications.requestPermissionIfNeeded(preferences: value); self.evaluateModelAlerts(force: true); self.render(); return true
            }
            preferencesPanel = panel
        }
        if preferencesPanel?.resumeIfSuspended() != true {
            preferencesPanel?.present(preferences, providerLimitMicros: history.last.map { Int64($0.limitCents) * 10_000 })
        }
        notifications.readPermission()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showPreferences(); return false }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !pageIdle, webView === self.webView else { return }
        if awaitingBrowserSession, webView.url?.scheme == "https", DashboardLocation.destination(for: webView.url) == .signIn { browserSessionRejected() }
        if !window.isVisible && DashboardLocation.destination(for: webView.url) == .signIn { pauseLogin(); return }
        connectionFailed = false; sourceLoadedAt = Date(); readUsage()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { guard !pageIdle, webView === self.webView else { return }; connectionFailed = true; lastRead = .distantPast; message = QuotaMessages.unavailable("Cursor"); render() }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if exporter.capture(navigationAction.request) { return nil }
        if let url = navigationAction.request.url, url.scheme == "https" { webView.load(URLRequest(url: url)) }; return nil
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        if url == Self.blankPage { decisionHandler(.allow); return }
        if UsageExporter.isExport(url) { _ = exporter.capture(navigationAction.request); decisionHandler(.cancel); return }
        if !window.isVisible, navigationAction.targetFrame?.isMainFrame != false,
           DashboardLocation.destination(for: url) == .signIn {
            decisionHandler(.cancel); pauseLogin(); return
        }
        decisionHandler(url?.scheme == "https" ? .allow : .cancel)
    }
}
MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = CursorUsageApp(); application.delegate = delegate; withExtendedLifetime(delegate) { application.run() }
}
