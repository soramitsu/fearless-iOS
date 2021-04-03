protocol LanguageSelectionViewProtocol: SelectionListViewProtocol {}

protocol LanguageSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol LanguageSelectionInteractorInputProtocol: AnyObject {
    func load()
    func select(language: Language) -> Bool
}

protocol LanguageSelectionInteractorOutputProtocol: AnyObject {
    func didLoad(selectedLanguage: Language)
    func didLoad(languages: [Language])
}

protocol LanguageSelectionWireframeProtocol: AnyObject {
    func proceed(from view: LanguageSelectionViewProtocol?)
}

protocol LanguageSelectionViewFactoryProtocol: AnyObject {
    static func createView() -> LanguageSelectionViewProtocol?
}
