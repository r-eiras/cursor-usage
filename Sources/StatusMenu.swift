import AppKit

@MainActor enum StatusMenu {
    static func make(target: AnyObject, settings: Selector, about: Selector, updates: Selector, issues: Selector, logout: Selector, canDisconnect: Bool = true, quit: Selector) -> NSMenu {
        let menu = NSMenu(); menu.autoenablesItems = false
        func item(_ title: String, _ action: Selector, _ key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = target; menu.addItem(item)
        }
        item(L("Sobre o Cursor Usage", "About Cursor Usage"), about)
        item(L("Verificar atualizações…", "Check for Updates…"), updates)
        item(L("Reportar problema…", "Report an issue…"), issues)
        menu.addItem(.separator())
        item(L("Configurações…", "Settings…"), settings, ",")
        item(L("Desconectar conta", "Disconnect account"), logout)
        menu.items.last?.isEnabled = canDisconnect
        menu.addItem(.separator())
        item(L("Sair", "Quit"), quit, "q")
        return menu
    }
}
