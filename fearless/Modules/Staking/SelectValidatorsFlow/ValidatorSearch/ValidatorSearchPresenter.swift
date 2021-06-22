import SoraFoundation

final class ValidatorSearchPresenter {
    weak var view: ValidatorSearchViewProtocol?
    let wireframe: ValidatorSearchWireframeProtocol
    let interactor: ValidatorSearchInteractorInputProtocol
    let logger: LoggerProtocol?

    init(
        wireframe: ValidatorSearchWireframeProtocol,
        interactor: ValidatorSearchInteractorInputProtocol,
        localizationManager: LocalizationManager,
        logger: LoggerProtocol? = nil
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.localizationManager = localizationManager
    }

    #warning("Not implemented")
}

extension ValidatorSearchPresenter: ValidatorSearchPresenterProtocol {
    func setup() {
        // TODO: provideViewModels()?
        interactor.setup()
    }
}

extension ValidatorSearchPresenter: ValidatorSearchInteractorOutputProtocol {
    #warning("Not implemented")
}

extension ValidatorSearchPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            // TODO: provideViewModels()?
        }
    }
}
