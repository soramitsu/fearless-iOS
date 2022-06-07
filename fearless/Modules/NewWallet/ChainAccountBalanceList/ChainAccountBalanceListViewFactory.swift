import Foundation
import RobinHood
import SoraFoundation
import SoraKeystore

struct ChainAccountBalanceListViewFactory {
    static func createView(selectedMetaAccount: MetaAccountModel) -> ChainAccountBalanceListViewProtocol? {
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let mapper = AssetModelMapper()

        let assetRepository = SubstrateDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(mapper)
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = ChainAccountBalanceListInteractor(
            selectedMetaAccount: selectedMetaAccount,
            chainRepository: AnyDataProviderRepository(chainRepository),
            assetRepository: AnyDataProviderRepository(assetRepository),
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            eventCenter: EventCenter.shared,
            metaAccountRepository: accountRepository,
            jsonDataProviderFactory: JsonDataProviderFactory.shared
        )

        let wireframe = ChainAccountBalanceListWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountBalanceListViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let localizationManager = LocalizationManager.shared

        let presenter = ChainAccountBalanceListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = ChainAccountBalanceListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
