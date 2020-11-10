import Foundation
import SoraFoundation

final class LanguageSelectionPresenter {
    weak var view: LanguageSelectionViewProtocol?
    var wireframe: LanguageSelectionWireframeProtocol!
    var interactor: LanguageSelectionInteractorInputProtocol!

    private var viewModels: [SelectableSubtitleListViewModel] = []

    private var languages: [Language] = []

    private var selectedLanguage: Language?

    var logger: LoggerProtocol?

    private func updateView() {
        viewModels = languages.map {
            let isSelected: Bool = $0.code == selectedLanguage?.code
            let title: String

            let targetLocale = Locale(identifier: $0.code)
            let subtitle: String = $0.title(in: targetLocale)?.capitalized ?? ""

            if let localizationManager = localizationManager {
                let language = $0.title(in: localizationManager.selectedLocale)?.capitalized ?? ""

                if let regionTitle = $0.region(in: localizationManager.selectedLocale) {
                    title = "\(language) (\(regionTitle))"
                } else {
                    title = language
                }

            } else {
                title = ""
            }

            return SelectableSubtitleListViewModel(title: title,
                                                   subtitle: subtitle,
                                                   isSelected: isSelected)
        }

        view?.didReload()
    }

    private func updateSelectedLanguage() {
        for (index, viewModel) in viewModels.enumerated() {
            viewModel.isSelected = languages[index].code == selectedLanguage?.code
        }
    }
}

extension LanguageSelectionPresenter: LanguageSelectionPresenterProtocol {
    var numberOfItems: Int {
        return viewModels.count
    }

    func item(at index: Int) -> SelectableViewModelProtocol {
        return viewModels[index]
    }

    func selectItem(at index: Int) {
        if interactor.select(language: languages[index]) {
            wireframe.proceed(from: view)
        }
    }

    func setup() {
        interactor.load()
    }
}

extension LanguageSelectionPresenter: LanguageSelectionInteractorOutputProtocol {
    func didLoad(selectedLanguage: Language) {
        self.selectedLanguage = selectedLanguage
        updateSelectedLanguage()
    }

    func didLoad(languages: [Language]) {
        self.languages = languages
        updateView()
    }
}

extension LanguageSelectionPresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            updateView()
        }
    }
}
