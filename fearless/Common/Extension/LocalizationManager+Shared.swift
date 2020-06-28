import Foundation
import SoraFoundation
import SoraKeystore

extension LocalizationManagerProtocol {
    var preferredLocalizations: [String]? {
        return [selectedLocalization]
    }

    var selectedLanguage: Language {
        return Language(code: selectedLocalization)
    }
}

extension LocalizationManager {
    static let shared = LocalizationManager(settings: SettingsManager.shared,
                                            key: SettingsKey.selectedLocalization.rawValue)
}
