import AppKit

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
final class Target: NSObject { var clicks = 0; @objc func tap() { clicks += 1 } }

MainActor.assumeIsolated {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    // Same window the app opens for the embedded sign-in.
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Cursor Usage — sign in to the official Cursor dashboard"; window.contentView = NSView()
    let target = Target()
    let button = BrowserSignInButton.install(in: window, target: target, action: #selector(Target.tap))
    AppLanguage.current = .portuguese; BrowserSignInButton.update(button, waiting: false)
    window.orderFrontRegardless(); window.layoutIfNeeded(); window.displayIfNeeded()

    let host = button.superview!, frame = button.convert(button.bounds, to: nil)
    check(button.title == "Entrar pelo navegador (passkey)", "Offer the browser sign-in in Portuguese")
    check(button.window === window && !button.isHidden && !host.isHidden, "The button lives in the sign-in window")
    check(button.frame.width > 120 && button.frame.height >= 16, "The button has a readable size")
    check(host.frame.width >= button.frame.maxX && host.frame.height >= button.frame.maxY, "The titlebar slot does not clip the button")
    check(frame.minY >= window.contentLayoutRect.maxY - 1, "The button sits in the titlebar, above the page")
    check(frame.minX > window.frame.width / 2 && frame.maxX <= window.frame.width, "The button sits at the trailing edge")
    button.performClick(nil); check(target.clicks == 1, "A click reaches the sign-in action")

    BrowserSignInButton.update(button, waiting: true)
    check(button.title == "Cancelar login no navegador" && host.frame.width >= button.frame.maxX, "While waiting, the same button cancels and still fits")
    AppLanguage.current = .english; BrowserSignInButton.update(button, waiting: false)
    check(button.title == "Sign in with browser (passkey)" && button.toolTip?.contains("passkey") == true, "Follow the interface language")
    print("PASS: browser sign-in titlebar button placement, sizing, click, waiting state and localization"); exit(0)
}
