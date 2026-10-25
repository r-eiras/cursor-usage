import Foundation
import ServiceManagement

enum LoginItemState {
    case disabled, enabled, requiresApproval, unavailable
    init(systemStatus: SMAppService.Status) {
        switch systemStatus {
        case .enabled: self = .enabled
        case .requiresApproval: self = .requiresApproval
        case .notRegistered: self = .disabled
        case .notFound: self = .unavailable
        @unknown default: self = .unavailable
        }
    }
    var selected: Bool { self == .enabled || self == .requiresApproval }
    var message: String {
        switch self {
        case .disabled: return L("Desligado · aplicado ao clicar, independentemente de Salvar.", "Off · applied on click, regardless of Save.")
        case .enabled: return L("Ativado · abrirá na barra ao entrar na sua conta do Mac.", "On · opens in the menu bar when you log in to your Mac.")
        case .requiresApproval: return L("Aguardando aprovação em Ajustes do Sistema → Itens de Início.", "Waiting for approval in System Settings → Login Items.")
        case .unavailable: return L("O macOS não encontrou o app para registrar o início automático.", "macOS could not find the app to register it as a login item.")
        }
    }
}

protocol LoginItemService: AnyObject {
    var state: LoginItemState { get }
    func register() throws
    func unregister() throws
}

private final class SystemLoginItemService: LoginItemService {
    var state: LoginItemState {
        LoginItemState(systemStatus: SMAppService.mainApp.status)
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

final class LoginItemManager {
    private let service: LoginItemService
    init(service: LoginItemService? = nil) { self.service = service ?? SystemLoginItemService() }
    var state: LoginItemState { service.state }
    func setEnabled(_ enabled: Bool) throws {
        guard enabled != state.selected else { return }
        if enabled { try service.register() } else { try service.unregister() }
    }
    static func failureMessage(_ error: Error, state: LoginItemState) -> String {
        if state == .unavailable {
            return L("O macOS não encontrou o app. Mova-o para Aplicativos e reabra antes de ativar esta opção.", "macOS could not find the app. Move it to Applications and reopen it before enabling this option.")
        }
        return L("Não foi possível alterar o início automático: ", "Could not change the login item: ") + error.localizedDescription
    }
    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
