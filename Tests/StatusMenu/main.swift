import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
@MainActor final class Actions: NSObject {
    var invoked = [String]()
    @objc func settings() { invoked.append("settings") }
    @objc func about() { invoked.append("about") }
    @objc func updates() { invoked.append("updates") }
    @objc func logout() { invoked.append("logout") }
    @objc func quit() { invoked.append("quit") }
}
MainActor.assumeIsolated {
    _ = NSApplication.shared
    let rightArea = NSRect(x: 848, y: 950, width: 664, height: 32)
    check(StatusItemPlacement.needsRecovery(frame: NSRect(x: 798, y: 949, width: 117, height: 33), rightArea: rightArea), "An item partially behind the camera cutout is recovered")
    check(StatusItemPlacement.needsRecovery(frame: NSRect(x: 710, y: 949, width: 100, height: 33), rightArea: rightArea), "An item entirely behind the cutout is recovered")
    check(!StatusItemPlacement.needsRecovery(frame: NSRect(x: 883, y: 949, width: 117, height: 33), rightArea: rightArea), "A fully visible item keeps its position")
    check(!StatusItemPlacement.needsRecovery(frame: .zero, rightArea: rightArea), "An unlaid-out item is not repeatedly recreated")
    check(!StatusItemPlacement.needsRecovery(frame: NSRect(x: 798, y: 949, width: 117, height: 33), rightArea: nil), "A screen without a camera cutout keeps its position")
    for language in [AppLanguage.portuguese, .english] {
        AppLanguage.current = language
        let target = Actions()
        let menu = StatusMenu.make(target: target, settings: #selector(Actions.settings), about: #selector(Actions.about), updates: #selector(Actions.updates), logout: #selector(Actions.logout), quit: #selector(Actions.quit))
        check(menu.items.filter { !$0.isSeparatorItem }.map(\.title) == [L("Sobre o Cursor Usage", "About Cursor Usage"), L("Verificar atualizações…", "Check for Updates…"), L("Configurações…", "Settings…"), L("Desconectar conta", "Disconnect account"), L("Sair", "Quit")], "Context menu contains the requested app actions")
        for index in [0, 1, 3, 4, 6] { menu.performActionForItem(at: index) }
        check(target.invoked == ["about", "updates", "settings", "logout", "quit"], "All context menu items reach their action target")
        let disconnectedMenu = StatusMenu.make(target: target, settings: #selector(Actions.settings), about: #selector(Actions.about), updates: #selector(Actions.updates), logout: #selector(Actions.logout), canDisconnect: false, quit: #selector(Actions.quit))
        check(!disconnectedMenu.items[4].isEnabled, "Logout is unavailable when this app is already disconnected")
        check(menu.items[3].keyEquivalent == "," && menu.items[6].keyEquivalent == "q", "Settings and quit retain native keyboard shortcuts")
    }
    print("PASS: camera-cutout placement recovery, right-click menu actions and localization")
}
