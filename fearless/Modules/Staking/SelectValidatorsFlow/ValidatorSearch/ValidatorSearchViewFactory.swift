import SoraFoundation

struct ValidatorSearchViewFactory: ValidatorSearchViewFactoryProtocol {
    static func createView() -> ValidatorSearchViewProtocol? {
        let interactor = ValidatorSearchInteractor()

        let wireframe = ValidatorSearchWireframe()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        return view
    }
}
