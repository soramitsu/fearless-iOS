import SoraFoundation

protocol ValidatorSearchWireframeProtocol {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )
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

    func didSelectValidator(at index: Int)
}

protocol ValidatorSearchViewFactoryProtocol {
    static func createView() -> ValidatorSearchViewProtocol?
    #warning("Not implemented")
}
