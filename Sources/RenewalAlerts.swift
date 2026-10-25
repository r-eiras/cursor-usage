import Foundation

struct RenewalEvent { let id: String; let title: String; let body: String }
enum RenewalDetector {
    static func event(previousReset: Date?, currentReset: Date?, observedAt: Date) -> RenewalEvent? {
        guard let previous = previousReset, previous.timeIntervalSince1970 > 0, previous <= observedAt,
              let current = currentReset, current > previous, current.timeIntervalSince(observedAt) >= 15 * 86400 else { return nil }
        let formatter = DateFormatter(); formatter.locale = AppLanguage.locale; formatter.dateStyle = .medium; formatter.timeStyle = .short
        return RenewalEvent(id: "cursor-renewal:\(Int(previous.timeIntervalSince1970))", title: L("Cursor: cota renovada", "Cursor: quota renewed"), body: L("Próxima renovação: \(formatter.string(from: current)).", "Next renewal: \(formatter.string(from: current))."))
    }
}
