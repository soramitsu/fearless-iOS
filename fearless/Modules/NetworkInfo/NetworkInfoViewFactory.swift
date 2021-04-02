import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class NetworkInfoViewFactory: NetworkInfoViewFactoryProtocol {
    static func createView(with connectionItem: ConnectionItem, mode: NetworkInfoMode) -> NetworkInfoViewProtocol? {
        let mapper = ManagedConnectionItemMapper()
        let repository = UserDataStorageFacade.shared
            .createRepository(
                filter: nil,
                sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                mapper: AnyCoreDataMapper(mapper)
            )

        let view = NetworkInfoViewController(nib: R.nib.networkInfoViewController)
        let presenter = NetworkInfoPresenter(
            connectionItem: connectionItem,
            mode: mode,
            localizationManager: LocalizationManager.shared
        )

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)
        let interactor = NetworkInfoInteractor(
            repository: AnyDataProviderRepository(repository),
            substrateOperationFactory: substrateOperationFactory,
            settingsManager: SettingsManager.shared,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )
        let wireframe = NetworkInfoWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
