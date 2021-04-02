import Foundation
import SoraFoundation
import RobinHood
import FearlessUtils
import IrohaCrypto
import SoraKeystore

final class AccountManagementViewFactory: AccountManagementViewFactoryProtocol {
    static func createViewForSettings() -> AccountManagementViewProtocol? {
        let wireframe = AccountManagementWireframe()
        return createView(for: wireframe)
    }

    static func createViewForSwitch() -> AccountManagementViewProtocol? {
        let wireframe = SwitchAccount.AccountManagementWireframe()
        return createView(for: wireframe)
    }

    private static func createView(for wireframe: AccountManagementWireframeProtocol)
        -> AccountManagementViewProtocol?
    {
        let facade = UserDataStorageFacade.shared
        let mapper = ManagedAccountItemMapper()
        let observer: CoreDataContextObservable<ManagedAccountItem, CDAccountItem> =
            CoreDataContextObservable(
                service: facade.databaseService,
                mapper: AnyCoreDataMapper(mapper),
                predicate: { _ in true }
            )
        let repository = facade.createRepository(
            filter: nil,
            sortDescriptors: [NSSortDescriptor.accountsByOrder],
            mapper: AnyCoreDataMapper(mapper)
        )

        let view = AccountManagementViewController(nib: R.nib.accountManagementViewController)

        let iconGenerator = PolkadotIconGenerator()
        let viewModelFactory = ManagedAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            supportedNetworks: SNAddressType.supported
        )

        let anyObserver = AnyDataProviderRepositoryObservable(observer)
        let interactor = AccountManagementInteractor(
            repository: AnyDataProviderRepository(repository),
            repositoryObservable: anyObserver,
            settings: SettingsManager.shared,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
