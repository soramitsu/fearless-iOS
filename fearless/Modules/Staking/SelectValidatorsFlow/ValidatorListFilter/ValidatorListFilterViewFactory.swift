import SoraFoundation
import SoraKeystore

struct ValidatorListFilterViewFactory: ValidatorListFilterViewFactoryProtocol {
    private static func createContainer(flow: ValidatorListFilterFlow) -> ValidatorListFilterDependencyContainer? {
        switch flow {
        case let .relaychain(filter):
            let viewModelState = ValidatorListFilterRelaychainViewModelState(filter: filter)
            let viewModelFactory = ValidatorListFilterRelaychainViewModelFactory()
            let container = ValidatorListFilterDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )

            return container
        case let .parachain(filter):
            let viewModelState = ValidatorListFilterParachainViewModelState(filter: filter)
            let viewModelFactory = ValidatorListFilterParachainViewModelFactory()
            let container = ValidatorListFilterDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
            return container
        }
    }

    static func createView(
        asset: AssetModel,
        flow: ValidatorListFilterFlow,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol? {
        guard let container = createContainer(flow: flow) else {
            return nil
        }

        let wireframe = ValidatorListFilterWireframe()

        let presenter = ValidatorListFilterPresenter(
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            asset: asset,
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
