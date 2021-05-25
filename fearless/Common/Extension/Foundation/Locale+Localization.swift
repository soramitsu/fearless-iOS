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
