import AppKit
func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
@MainActor final class Actions: NSObject {
    var invoked = [String]()
    @objc func settings() { invoked.append("settings") }
    @objc func about() { invoked.append("about") }
    @objc func updates() { invoked.append("updates") }
    @objc func issues() { invoked.append("issues") }
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
        let menu = StatusMenu.make(target: target, settings: #selector(Actions.settings), about: #selector(Actions.about), updates: #selector(Actions.updates), issues: #selector(Actions.issues), logout: #selector(Actions.logout), quit: #selector(Actions.quit))
        check(menu.items.filter { !$0.isSeparatorItem }.map(\.title) == [L("Sobre o Cursor Usage", "About Cursor Usage"), L("Verificar atualizações…", "Check for Updates…"), L("Reportar problema…", "Report an issue…"), L("Configurações…", "Settings…"), L("Desconectar conta", "Disconnect account"), L("Sair", "Quit")], "Context menu contains the requested app actions")
        for index in [0, 1, 2, 4, 5, 7] { menu.performActionForItem(at: index) }
        check(target.invoked == ["about", "updates", "issues", "settings", "logout", "quit"], "All context menu items reach their action target")
        let disconnectedMenu = StatusMenu.make(target: target, settings: #selector(Actions.settings), about: #selector(Actions.about), updates: #selector(Actions.updates), issues: #selector(Actions.issues), logout: #selector(Actions.logout), canDisconnect: false, quit: #selector(Actions.quit))
        check(!disconnectedMenu.items[5].isEnabled, "Logout is unavailable when this app is already disconnected")
        check(menu.items[4].keyEquivalent == "," && menu.items[7].keyEquivalent == "q", "Settings and quit retain native keyboard shortcuts")
        let updateMenu = StatusMenu.make(target: target, settings: #selector(Actions.settings), about: #selector(Actions.about), updates: #selector(Actions.updates), issues: #selector(Actions.issues), logout: #selector(Actions.logout), quit: #selector(Actions.quit), update: (title: L("Atualizar para 9.1.0…", "Update to 9.1.0…"), action: #selector(Actions.updates)))
        check(updateMenu.items[0].title == L("Atualizar para 9.1.0…", "Update to 9.1.0…") && updateMenu.items[1].isSeparatorItem && updateMenu.items[2].title == L("Sobre o Cursor Usage", "About Cursor Usage"), "An available update leads the menu")
        target.invoked.removeAll(); updateMenu.performActionForItem(at: 0); check(target.invoked == ["updates"], "The update item reaches its action")
    }
    print("PASS: camera-cutout placement recovery, right-click menu actions and localization")
}
