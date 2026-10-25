import Foundation
import SoraFoundation

extension Locale {
    var rLanguages: [String]? {
        [identifier]
    }
}

extension Localizable {
    var selectedLocale: Locale { localizationManager?.selectedLocale ?? Locale.current }
}

extension Bundle {
    /// The string table for `locale`, matched the way iOS matches a preferred language to the
    /// app's localizations: "en_US" reads en, "zh_CN" or "zh-SG" reads zh-Hans, "pt-BR" reads
    /// pt-PT, "in" reads id. A language the app has no table for reads the development
    /// language (English), never whatever language the device happens to use.
    static func localizationBundle(for locale: Locale, in bundle: Bundle = .main) -> Bundle {
        let development = bundle.developmentLocalization ?? "en"
        let available = bundle.localizations.filter { $0 != "Base" }
        let match = Bundle.preferredLocalizations(from: available, forPreferences: [locale.identifier]).first
        let name: String
        if let match, Locale(identifier: match).languageCode == locale.languageCode {
            name = match
        } else {
            name = development
        }

        guard let path = bundle.path(forResource: name, ofType: "lproj"),
              let localized = Bundle(path: path) else {
            return bundle
        }
        return localized
    }
}
