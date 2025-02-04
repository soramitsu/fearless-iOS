import Foundation
import SoraFoundation

extension Locale {
    var rLanguages: [String]? {
        [identifier]
    }
    
    static var enUS: Locale {
        return Locale(identifier: "en_US_POSIX")
    }
}

extension Localizable {
    var selectedLocale: Locale { localizationManager?.selectedLocale ?? Locale.current }
}
