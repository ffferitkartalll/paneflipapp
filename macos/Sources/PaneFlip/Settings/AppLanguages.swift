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

    /// A language as shown in the picker: in its own language.
    func title(of code: String) -> String {
        if code == SettingsValues.systemLanguage { return String(localized: "System language") }
        return Locale(identifier: code).localizedString(forLanguageCode: code)?.localizedCapitalized ?? code
    }

    private static func languageCode(_ identifier: String) -> String? {
        Locale.Language(identifier: identifier).languageCode?.identifier
    }
}
