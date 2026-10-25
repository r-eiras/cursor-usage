import AppKit

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
MainActor.assumeIsolated {
    let local = NotificationCenter(), workspace = NotificationCenter()
    var closed = 0, inside = false
    let dismissal = PopoverDismissal(notifications: local, workspaceNotifications: workspace, isInside: { _ in inside }, dismiss: { closed += 1 })
    dismissal.start(monitorClicks: false)
    local.post(name: NSApplication.didResignActiveNotification, object: nil)
    check(closed == 1, "Close when the application loses focus")
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    check(closed == 2, "Close when switching desktops instead of following the user")
    inside = true
    dismissal.handleLocalClick(in: nil)
    check(closed == 2, "Keep controls and the status button usable without closing and reopening")
    inside = false
    dismissal.handleLocalClick(in: nil)
    check(closed == 3, "Close on a click in a different window of the same app")
    dismissal.stop()
    local.post(name: NSApplication.didResignActiveNotification, object: nil)
    workspace.post(name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    check(closed == 3, "Remove observers when the popup closes")
    dismissal.start(monitorClicks: false); dismissal.start(monitorClicks: false)
    local.post(name: NSApplication.didResignActiveNotification, object: nil)
    check(closed == 4, "Reopening must not duplicate observers")
    dismissal.stop()
    print("PASS: popover focus loss, desktop changes, click boundaries and observer lifecycle")
}
