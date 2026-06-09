import Foundation
import FearlessFoundation
import FearlessSecureStorage

extension LocalizationManagerProtocol {
    var preferredLocalizations: [String]? {
        [selectedLocalization]
    }

    var selectedLanguage: Language {
        Language(code: selectedLocalization)
    }
}

extension LocalizationManager {
    static let shared = LocalizationManager(
        settings: SettingsManager.shared,
        key: SettingsKey.selectedLocalization.rawValue
    )
}
