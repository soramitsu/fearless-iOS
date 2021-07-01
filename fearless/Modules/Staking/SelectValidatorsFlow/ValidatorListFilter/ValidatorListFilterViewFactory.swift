import SoraFoundation
import SoraKeystore

struct ValidatorListFilterViewFactory: ValidatorListFilterViewFactoryProtocol {
    static func createView(
        with filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        let wireframe = ValidatorListFilterWireframe()

        let viewModelFactory = ValidatorListFilterViewModelFactory()

        let settings = SettingsManager.shared
        let addressType = settings.selectedConnection.type
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)
        let asset = primitiveFactory.createAssetForAddressType(addressType)

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

        presenter.delegate = delegate

        return view
    }
}
