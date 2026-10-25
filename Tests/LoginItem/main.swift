import Foundation
import ServiceManagement

func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
final class FakeService: LoginItemService {
    var state: LoginItemState = .disabled
    var registrations = 0
    var removals = 0
    var fails = false
    var approvalRequired = false
    func register() throws {
        registrations += 1
        if fails { throw NSError(domain: "Test", code: 1) }
        state = approvalRequired ? .requiresApproval : .enabled
    }
    func unregister() throws { removals += 1; state = .disabled }
}
check(LoginItemState(systemStatus: .notFound) == .unavailable, "A missing application is unavailable rather than merely disabled")
check(LoginItemState(systemStatus: .notRegistered) == .disabled, "An unregistered application remains a normal disabled option")
let service = FakeService()
let manager = LoginItemManager(service: service)
check(manager.state == .disabled, "Opening settings must not enable login items")
try manager.setEnabled(true)
check(manager.state == .enabled && service.registrations == 1, "Explicit opt-in registers the application")
try manager.setEnabled(true)
check(service.registrations == 1, "Do not register again when already enabled")
service.state = .disabled
check(manager.state == .disabled, "Read changes made externally in System Settings")
service.approvalRequired = true
try manager.setEnabled(true)
check(manager.state == .requiresApproval, "Pending approval must not be reported as enabled")
try manager.setEnabled(false)
check(manager.state == .disabled && service.removals == 1, "Allow cancelling a pending registration")
service.fails = true
var failed = false
do { try manager.setEnabled(true) } catch { failed = true }
check(failed && manager.state == .disabled, "Propagate failure without pretending startup was enabled")
let diagnostic = NSError(domain: "Fixture", code: 7, userInfo: [NSLocalizedDescriptionKey: "Synthetic registration failure"])
for language in [AppLanguage.portuguese, .english] {
    AppLanguage.current = language
    check(LoginItemManager.failureMessage(diagnostic, state: .disabled).contains("Synthetic registration failure"), "Registration failures retain their useful cause")
    check(!LoginItemManager.failureMessage(diagnostic, state: .unavailable).contains("Synthetic registration failure"), "A missing app gets actionable installation guidance")
}
print("PASS: login item opt-in, external state, approval, removal and errors")
