import SoraFoundation

protocol ValidatorSearchWireframeProtocol {
    #warning("Not implemented")
}

protocol ValidatorSearchViewProtocol: ControllerBackedProtocol, Localizable {
    #warning("Not implemented")
    // Did receive validator?
    // Did start search?
    // Did finish serach?
    // Did receive search results
}

protocol ValidatorSearchInteractorInputProtocol {
    func setup()
}

protocol ValidatorSearchInteractorOutputProtocol {
    #warning("Not implemented")
    // Did receive validator
}

protocol ValidatorSearchPresenterProtocol: Localizable {
    func setup()
}

protocol ValidatorSearchViewFactoryProtocol {
    func createView() -> ValidatorSearchViewProtocol
    #warning("Not implemented")
}
