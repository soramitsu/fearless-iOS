import Foundation
import SoraFoundation
import RobinHood
import SSFUtils
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

    private static func createView(
        for wireframe: AccountManagementWireframeProtocol
    ) -> AccountManagementViewProtocol? {
        let facade = UserDataStorageFacade.shared
        let mapper = ManagedMetaAccountMapper()
        let localizationManager = LocalizationManager.shared

        let observer: CoreDataContextObservable<ManagedMetaAccountModel, CDMetaAccount> =
            CoreDataContextObservable(
                service: facade.databaseService,
                mapper: AnyCoreDataMapper(mapper),
                predicate: { _ in true }
            )

        let repository = AccountRepositoryFactory(storageFacade: facade)
            .createManagedMetaAccountRepository(
                for: nil,
                sortDescriptors: [NSSortDescriptor.accountsByOrder]
            )

        let view = AccountManagementViewController(nib: R.nib.accountManagementViewController)
        view.localizationManager = LocalizationManager.shared

        let iconGenerator = UniversalIconGenerator()
        let viewModelFactory = ManagedAccountViewModelFactory(iconGenerator: iconGenerator)

        let presenter = AccountManagementPresenter(
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let getBalanceProvider = GetBalanceProvider(
            balanceForModel: .managedMetaAccounts,
            chainModelRepository: AnyDataProviderRepository(chainRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let anyObserver = AnyDataProviderRepositoryObservable(observer)
        let interactor = AccountManagementInteractor(
            repository: AnyDataProviderRepository(repository),
            repositoryObservable: anyObserver,
            settings: SelectedWalletSettings.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            getBalanceProvider: getBalanceProvider
        )

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
