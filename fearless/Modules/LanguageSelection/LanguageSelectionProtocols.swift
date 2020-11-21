protocol LanguageSelectionViewProtocol: SelectionListViewProtocol {}

protocol LanguageSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol LanguageSelectionInteractorInputProtocol: class {
    func load()
    func select(language: Language) -> Bool
}

protocol LanguageSelectionInteractorOutputProtocol: class {
    func didLoad(selectedLanguage: Language)
    func didLoad(languages: [Language])
}

protocol LanguageSelectionWireframeProtocol: class {
    func proceed(from view: LanguageSelectionViewProtocol?)
}

protocol LanguageSelectionViewFactoryProtocol: class {
	static func createView() -> LanguageSelectionViewProtocol?
}
