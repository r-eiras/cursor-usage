import Foundation

// Interface language. `system` follows macOS: Portuguese when it leads the preferred
// languages, English otherwise. Only two languages, so each text is written as an inline pair.
enum AppLanguage: String, Codable, CaseIterable {
    case system, portuguese, english
    nonisolated(unsafe) static var current: AppLanguage = .system
    static var isPortuguese: Bool {
        switch current {
        case .portuguese: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.hasPrefix("pt") ?? false
        }
    }
    static var locale: Locale { Locale(identifier: isPortuguese ? "pt_BR" : "en_US") }
    // Native names, so each option stays readable whichever language is active.
    var title: String {
        switch self { case .system: return L("Idioma do sistema", "System language"); case .portuguese: return "Português"; case .english: return "English" }
    }
}

func L(_ portuguese: String, _ english: String) -> String { AppLanguage.isPortuguese ? portuguese : english }

// Decimal separator for numbers formatted with a fixed "%.1f"-style format.
func localizedDecimal(_ value: String) -> String { AppLanguage.isPortuguese ? value.replacingOccurrences(of: ".", with: ",") : value }

enum AppFolder {
    static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("CursorUsage")
    }
}

enum QuotaMessages {
    static func waiting(_ name: String) -> String { L("Aguardando a primeira leitura de \(name)", "Waiting for the first \(name) reading") }
    static func checking(_ name: String) -> String { L("Consultando cotas de \(name)…", "Checking \(name) quotas…") }
    static func synced(_ name: String) -> String { L("Cotas de \(name) atualizadas", "\(name) quotas updated") }
    static func unavailable(_ name: String) -> String { L("Cotas de \(name) indisponíveis; última leitura preservada", "\(name) quotas unavailable; last reading kept") }
    static func alertTitle(_ name: String, daily: Bool = false) -> String {
        daily ? L("\(name): alerta de cota diária", "\(name): daily quota alert") : L("\(name): alerta de cota", "\(name): quota alert")
    }
}

extension QuotaMessages {
    static func cycleAlertBody(used: String, goal: String) -> String {
        L("Consumo da janela: \(used) de uma meta de \(goal). Consulte sua meta no Cursor Usage.", "Window usage: \(used) of a \(goal) goal. Check your goal in Cursor Usage.")
    }
    static func dailyAlertBody(used: String, threshold: String, allowance: String) -> String {
        L("Uso observado hoje: \(used). Aviso em: \(threshold). Cota diária: \(allowance). Consulte sua meta no Cursor Usage.", "Observed usage today: \(used). Alert at: \(threshold). Daily quota: \(allowance). Check your goal in Cursor Usage.")
    }
}
