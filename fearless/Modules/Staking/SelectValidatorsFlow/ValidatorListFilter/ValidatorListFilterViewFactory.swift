import SoraFoundation
import SoraKeystore

struct ValidatorListFilterViewFactory: ValidatorListFilterViewFactoryProtocol {
    static func createView(
        asset: AssetModel,
        with filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        let wireframe = ValidatorListFilterWireframe()

        let viewModelFactory = ValidatorListFilterViewModelFactory()

        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            asset: asset,
            filter: filter,
            localizationManager: LocalizationManager.shared
        )

        let view = ValidatorListFilterViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        presenter.delegate = delegate

        return view
    }
}
