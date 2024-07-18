import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFNetwork

final class WalletMainContainerAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        walletConnect: WalletConnectService
    ) -> WalletMainContainerModuleCreationResult? {
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

        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )
        let deprecatedAccountsCheckService = DeprecatedControllerStashAccountCheckService(
            chainRegistry: chainRegistry,
            chainRepository: AnyDataProviderRepository(chainRepository),
            storageRequestFactory: storageOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            walletRepository: AnyDataProviderRepository(accountRepository),
            stashItemRepository: substrateRepositoryFactory.createStashItemRepository()
        )
        let accountStatisticsFetcher = NomisAccountStatisticsFetcher(networkWorker: NetworkWorkerImpl(), signer: NomisRequestSigner())
        let interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            deprecatedAccountsCheckService: deprecatedAccountsCheckService,
            applicationHandler: ApplicationHandler(),
            walletConnectService: walletConnect,
            accountStatisticsFetcher: accountStatisticsFetcher
        )

        let router = WalletMainContainerRouter()

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(wallet: wallet),
            let assetListModule = Self.configureAssetListModule(metaAccount: wallet),
            let nftModule = Self.configureNftModule(wallet: wallet)
        else {
            return nil
        }

        let presenter = WalletMainContainerPresenter(
            balanceInfoModuleInput: balanceInfoModule.input,
            assetListModuleInput: assetListModule.input,
            nftModuleInput: nftModule.input,
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

    // MARK: - Cofigure Modules

    private static func configureBalanceInfoModule(
        wallet: MetaAccountModel
    ) -> BalanceInfoModuleCreationResult? {
        BalanceInfoAssembly.configureModule(with: .networkManagement(wallet: wallet))
    }

    private static func configureAssetListModule(
        metaAccount: MetaAccountModel
    ) -> ChainAssetListModuleCreationResult? {
        ChainAssetListAssembly.configureModule(wallet: metaAccount, keyboardAdoptable: false)
    }

    private static func configureNftModule(wallet: MetaAccountModel) -> MainNftContainerModuleCreationResult? {
        MainNftContainerAssembly.configureModule(wallet: wallet)
    }
}
