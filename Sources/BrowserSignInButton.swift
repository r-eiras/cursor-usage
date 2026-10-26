import AppKit

// The titlebar button that offers the browser sign-in beside the embedded page.
@MainActor enum BrowserSignInButton {
    static func install(in window: NSWindow, target: AnyObject, action: Selector) -> NSButton {
        let button = NSButton(title: "", target: target, action: action)
        button.bezelStyle = .rounded; button.controlSize = .small; button.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let accessory = NSTitlebarAccessoryViewController(); accessory.layoutAttribute = .trailing
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 28)); accessory.view.addSubview(button)
        window.addTitlebarAccessoryViewController(accessory)
        return button
    }
    static func update(_ button: NSButton, waiting: Bool) {
        button.title = waiting ? L("Cancelar login no navegador", "Cancel browser sign-in") : L("Entrar pelo navegador (passkey)", "Sign in with browser (passkey)")
        button.toolTip = L("Use se o login nesta janela não funcionar, como numa conta Google protegida por passkey.", "Use this if signing in here doesn't work, such as a Google account protected by a passkey.")
        button.sizeToFit()
        guard let host = button.superview else { return }
        host.setFrameSize(NSSize(width: button.frame.width + 12, height: host.frame.height))
        button.setFrameOrigin(NSPoint(x: 4, y: max(0, (host.frame.height - button.frame.height) / 2)))
    }
}
