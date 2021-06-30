import SoraFoundation

struct ValidatorSearchViewFactory: ValidatorSearchViewFactoryProtocol {
    static func createView(
        with validators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    ) -> ValidatorSearchViewProtocol? {
        let interactor = ValidatorSearchInteractor()

        let wireframe = ValidatorSearchWireframe()

        let viewModelFactory = ValidatorSearchViewModelFactory()

        let presenter = ValidatorSearchPresenter(
            wireframe: wireframe,
            interactor: interactor,
            viewModelFactory: viewModelFactory,
            allValidators: validators,
            selectedValidators: selectedValidators,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.delegate = delegate

        let view = ValidatorSearchViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
