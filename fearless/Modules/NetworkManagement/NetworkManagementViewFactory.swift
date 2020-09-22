import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class NetworkManagementViewFactory: NetworkManagementViewFactoryProtocol {
    static func createView() -> NetworkManagementViewProtocol? {
        let view = NetworkManagementViewController(nib: R.nib.networkManagementViewController)

        let facade = UserDataStorageFacade.shared
        let connectionsMapper = ManagedConnectionItemMapper()
        let observer: CoreDataContextObservable<ManagedConnectionItem, CDConnectionItem> =
            CoreDataContextObservable(service: facade.databaseService,
                                                 mapper: AnyCoreDataMapper(connectionsMapper),
                                                 predicate: { _ in true })
        let connectionsRepository = facade.createRepository(filter: nil,
                                                            sortDescriptors: [NSSortDescriptor.connectionsByOrder],
                                                            mapper: AnyCoreDataMapper(connectionsMapper))

        let presenter = NetworkManagementPresenter(localizationManager: LocalizationManager.shared,
                                                   viewModelFactory: ManagedConnectionViewModelFactory())

        let connectionsObservable = AnyDataProviderRepositoryObservable(observer)

        let accountsMapper = ManagedAccountItemMapper()
        let accountsRepository = facade.createRepository(filter: nil,
                                                         sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                         mapper: AnyCoreDataMapper(accountsMapper))

        let anyConnectionsRepository = AnyDataProviderRepository(connectionsRepository)
        let anyConnectionsObservable = AnyDataProviderRepositoryObservable(connectionsObservable)
        let anyAccountRepository = AnyDataProviderRepository(accountsRepository)
        let interactor = NetworkManagementInteractor(connectionsRepository: anyConnectionsRepository,
                                                     connectionsObservable: anyConnectionsObservable,
                                                     accountsRepository: anyAccountRepository,
                                                     settings: SettingsManager.shared,
                                                     operationManager: OperationManagerFacade.sharedManager,
                                                     eventCenter: EventCenter.shared)
        let wireframe = NetworkManagementWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
