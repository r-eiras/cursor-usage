import AppKit

@MainActor final class PopoverDismissal {
    private let notifications: NotificationCenter
    private let workspaceNotifications: NotificationCenter
    private let isInside: (NSWindow?) -> Bool
    private let dismiss: () -> Void
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var monitors: [Any] = []
    private var started = false

    init(notifications: NotificationCenter = .default,
         workspaceNotifications: NotificationCenter = NSWorkspace.shared.notificationCenter,
         isInside: @escaping (NSWindow?) -> Bool, dismiss: @escaping () -> Void) {
        self.notifications = notifications; self.workspaceNotifications = workspaceNotifications
        self.isInside = isInside; self.dismiss = dismiss
    }
    func start(monitorClicks: Bool = true) {
        guard !started else { return }; started = true
        observe(notifications, NSApplication.didResignActiveNotification)
        observe(workspaceNotifications, NSWorkspace.activeSpaceDidChangeNotification)
        let activation = workspaceNotifications.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            MainActor.assumeIsolated { self?.dismiss() }
        }
        observers.append((workspaceNotifications, activation))
        guard monitorClicks else { return }
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handleLocalClick(in: event.window) }
            return event
        }) { monitors.append(monitor) }
    }
    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
        observers.append((center, observer))
    }
    func handleLocalClick(in window: NSWindow?) {
        guard started, !isInside(window) else { return }
        dismiss()
    }
    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }; monitors.removeAll()
        for (center, observer) in observers { center.removeObserver(observer) }; observers.removeAll()
        started = false
    }
}
