import Foundation
import PaneFlipCore

/// The languages the app can be shown in: whatever the string catalog has been translated into. Adding a language
/// to the catalog (by hand or with a translation service) adds it here; nothing in the code changes.
struct AppLanguages {
    let available: [String]
    private let preferred: [String]

    init(available: [String] = Bundle.main.localizations, preferred: [String] = Locale.preferredLanguages) {
        self.available = available.filter { $0 != "Base" }.sorted()
        self.preferred = preferred
    }

    /// The name of the system language when the app has no translation for it (it then shows English), else nil.
    var unavailableSystemLanguage: String? {
        guard let first = preferred.first, let code = Self.languageCode(first),
              !available.contains(where: { Self.languageCode($0) == code }) else { return nil }
        return Locale.current.localizedString(forLanguageCode: code) ?? first
    }

    /// A language as shown in the picker: in its own language. The region is added only where two translations share
    /// a language (Portuguese of Portugal and of Brazil), so a language that is alone is not named with its region.
    func title(of code: String) -> String {
        if code == SettingsValues.systemLanguage { return String(localized: "System language") }
        let shared = available.filter { Self.languageCode($0) == Self.languageCode(code) }.count > 1
        let identifier = shared ? distinguished(code) : (Self.languageCode(code) ?? code)
        return Locale(identifier: identifier).localizedString(forIdentifier: identifier)?.localizedCapitalized ?? code
    }

    /// The code with the region it stands for, so the bare `pt` next to `pt-BR` is named as `pt-PT`. The translation
    /// service exports Portugal's Portuguese as the bare code, while the likely region of `pt` is Brazil.
    /// shortcut: one known pair, add the language here when another exports the same way.
    private func distinguished(_ code: String) -> String {
        guard !code.contains("-"), !code.contains("_") else { return code }
        let language = Locale.Language(identifier: code)
        guard let base = language.languageCode?.identifier else { return code }
        if let region = Self.exportedRegions[base] { return "\(base)-\(region)" }
        let maximal = Locale.Language(identifier: language.maximalIdentifier)
        guard let region = maximal.region?.identifier else { return code }
        return "\(base)-\(region)"
    }

    private static let exportedRegions = ["pt": "PT"]

    private static func languageCode(_ identifier: String) -> String? {
        Locale.Language(identifier: identifier).languageCode?.identifier
    }
}
