import Foundation
import UserNotifications

// Where a clicked notification leads. Kept apart from delivery so the routing can be tested without macOS.
enum NotificationRoute: Equatable, Sendable {
    case update(String?), monitor(String), goal, models
    static let updateCategory = "update", installAction = "install", newModelCategory = "model-new", monitorAction = "monitor"
    static func of(category: String, userInfo: [AnyHashable: Any]) -> NotificationRoute {
        switch category {
        case updateCategory: return .update(userInfo["version"] as? String)
        case newModelCategory: return (userInfo["model"] as? String).map(NotificationRoute.monitor) ?? .models
        default: return userInfo["kind"] as? String == "models" ? .models : .goal
        }
    }
}

// How long a notice stays on screen is a macOS setting the app cannot change; this says what it is and how to change it.
enum NotificationAdvice {
    static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=local.cursorusage.CursorUsage")!
    static func message(authorization: UNAuthorizationStatus, style: UNAlertStyle) -> String {
        switch authorization {
        case .denied: return L("Notificações bloqueadas no macOS. Ative-as em Ajustes do Sistema → Notificações.", "Notifications are blocked in macOS. Turn them on in System Settings → Notifications.")
        case .notDetermined: return L("O macOS pede permissão no primeiro aviso.", "macOS asks for permission with the first notice.")
        default: break
        }
        switch style {
        case .alert: return L("Os avisos ficam na tela até você fechar.", "Notices stay on screen until you close them.")
        case .banner: return L("Os avisos aparecem como banners e somem em alguns segundos. Para que fiquem até você fechar, escolha Persistente nos Ajustes do macOS.", "Notices show as banners that disappear after a few seconds. To keep them until you close them, choose Persistent in macOS settings.")
        default: return L("Os avisos não aparecem na tela; ficam só na Central de Notificações. Escolha um estilo nos Ajustes do macOS.", "Notices don't show on screen; they only go to Notification Center. Choose a style in macOS settings.")
        }
    }
}
