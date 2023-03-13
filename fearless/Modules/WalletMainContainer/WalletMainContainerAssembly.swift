import UIKit
import SoraFoundation
import RobinHood

final class WalletMainContainerAssembly {
    static func configureModule(wallet: MetaAccountModel) -> WalletMainContainerModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let localizationManager = LocalizationManager.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: []
        )

        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let userRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = userRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetcher = AccountInfoFetching(
            accountInfoRepository: AnyDataProviderRepository(accountInfoRepository),
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: accountInfoFetcher
        )

        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let chainSettingsRepostiry = chainSettingsRepositoryFactory.createRepository()

        let interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: chainsIssuesCenter,
            chainSettingsRepository: AnyDataProviderRepository(chainSettingsRepostiry)
        )

        let router = WalletMainContainerRouter()

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(wallet: wallet),
            let assetListModule = Self.configureAssetListModule(
                metaAccount: wallet
            ),
            let nftModule = Self.configureNftModule()
        else {
            return nil
        }

        let presenter = WalletMainContainerPresenter(
            assetListModuleInput: assetListModule.input,
            wallet: wallet,
            viewModelFactory: WalletMainContainerViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletMainContainerViewController(
            balanceInfoViewController: balanceInfoModule.view.controller,
            pageControllers: [assetListModule.view.controller, nftModule.view.controller],
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func configureBalanceInfoModule(
        wallet: MetaAccountModel
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .wallet(wallet: wallet))
    }

    private static func configureAssetListModule(
        metaAccount: MetaAccountModel
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(wallet: metaAccount)
    }

    private static func configureNftModule() -> MainNftContainerModuleCreationResult? {
        MainNftContainerAssembly.configureModule()
    }
}
