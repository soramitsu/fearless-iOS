import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class NetworkManagementViewFactory: NetworkManagementViewFactoryProtocol {
    static func createView() -> NetworkManagementViewProtocol? {
        let view = NetworkManagementViewController(nib: R.nib.networkManagementViewController)

        let facade = UserDataStorageFacade.shared
        let mapper = ManagedConnectionItemMapper()
        let observer: CoreDataContextObservable<ManagedConnectionItem, CDConnectionItem> =
            CoreDataContextObservable(service: facade.databaseService,
                                                 mapper: AnyCoreDataMapper(mapper),
                                                 predicate: { _ in true })
        let repository = facade.createRepository(filter: nil,
                                                 sortDescriptors: [NSSortDescriptor.accountsByOrder],
                                                 mapper: AnyCoreDataMapper(mapper))

        let presenter = NetworkManagementPresenter(localizationManager: LocalizationManager.shared,
                                                   viewModelFactory: ManagedConnectionViewModelFactory())

        let repositoryObservable = AnyDataProviderRepositoryObservable(observer)
        let interactor = NetworkManagementInteractor(repository: AnyDataProviderRepository(repository),
                                                     repositoryObservable: repositoryObservable,
                                                     settings: SettingsManager.shared,
                                                     operationManager: OperationManagerFacade.sharedManager,
                                                     eventCenter: EventCenter.shared)
        let wireframe = NetworkManagementWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
