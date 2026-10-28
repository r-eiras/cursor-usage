import Foundation
import UserNotifications

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
check(NotificationRoute.of(category: "update", userInfo: ["version": "3.4.1"]) == .update("3.4.1"), "An update notice installs the version it announced")
check(NotificationRoute.of(category: "update", userInfo: [:]) == .update(nil), "An update notice from an older version falls back to a check")
check(NotificationRoute.of(category: "model-new", userInfo: ["kind": "models", "model": "gemini-argon"]) == .monitor("gemini-argon"), "A first-use notice opens settings with that model listed")
check(NotificationRoute.of(category: "model-new", userInfo: [:]) == .models, "A first-use notice without a model still opens the models")
check(NotificationRoute.of(category: "", userInfo: ["kind": "models"]) == .models, "Rate and limit notices open the card on its models")
check(NotificationRoute.of(category: "", userInfo: ["kind": "goal"]) == .goal && NotificationRoute.of(category: "", userInfo: [:]) == .goal, "Spending and renewal notices, and older ones without a kind, open the card on its goal")
for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    check(NotificationAdvice.message(authorization: .authorized, style: .banner).contains(L("Persistente", "Persistent")), "Temporary banners come with how to keep them on screen")
    check(NotificationAdvice.message(authorization: .authorized, style: .alert) == L("Os avisos ficam na tela até você fechar.", "Notices stay on screen until you close them."), "Persistent notices are confirmed as such")
    check(NotificationAdvice.message(authorization: .authorized, style: .none).contains(L("Central de Notificações", "Notification Center")), "No on-screen style says where notices still go")
    check(NotificationAdvice.message(authorization: .denied, style: .banner).contains(L("bloqueadas", "blocked")), "Blocked notifications say so before any style")
    check(NotificationAdvice.message(authorization: .notDetermined, style: .none).contains(L("primeiro aviso", "first notice")), "Before permission, the first notice asks")
}
check(NotificationAdvice.settingsURL.scheme == "x-apple.systempreferences" && NotificationAdvice.settingsURL.absoluteString.hasSuffix("id=local.cursorusage.CursorUsage"), "The settings shortcut opens this app's notification settings")
print("PASS: notification routes for every kind and advice for each macOS notification style")
