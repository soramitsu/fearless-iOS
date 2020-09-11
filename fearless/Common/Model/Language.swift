import Foundation

struct Language: Codable {
    let code: String
}

extension Language {
    func title(in locale: Locale) -> String? {
        let components = Locale.components(fromIdentifier: code)

        if let language = components[NSLocale.Key.languageCode.rawValue] {
            return locale.localizedString(forLanguageCode: language)
        } else {
            return nil
        }
    }

    func region(in locale: Locale) -> String? {
        let components = Locale.components(fromIdentifier: code)

        if let regionCode = components[NSLocale.Key.countryCode.rawValue] {
            return locale.localizedString(forRegionCode: regionCode)
        } else {
            return nil
        }
    }
}
