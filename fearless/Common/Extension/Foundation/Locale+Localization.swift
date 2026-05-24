import Foundation
import FearlessFoundation

extension Locale {
    var rLanguages: [String]? {
        [identifier]
    }
}

extension Localizable {
    var selectedLocale: Locale { localizationManager?.selectedLocale ?? Locale.current }
}
