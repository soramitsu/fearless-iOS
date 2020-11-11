import UIKit
import SoraFoundation

final class LanguageSelectionInteractor {
    weak var presenter: LanguageSelectionInteractorOutputProtocol!

    let localizationManager: LocalizationManagerProtocol

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }

    var logger: LoggerProtocol?
}

extension LanguageSelectionInteractor: LanguageSelectionInteractorInputProtocol {
    func load() {
        let languages: [Language] = localizationManager.availableLocalizations.map { localization in
            return Language(code: localization)
        }

        presenter.didLoad(languages: languages)

        presenter.didLoad(selectedLanguage: localizationManager.selectedLanguage)
    }

    func select(language: Language) -> Bool {
        if language.code != localizationManager.selectedLocalization {
            localizationManager.selectedLocalization = language.code

            presenter.didLoad(selectedLanguage: localizationManager.selectedLanguage)

            return true
        } else {
            return false
        }
    }
}
