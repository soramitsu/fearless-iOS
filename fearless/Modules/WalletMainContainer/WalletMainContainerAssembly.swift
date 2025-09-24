import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFNetwork
import SoraKeystore

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
        let accountScoreFetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerImpl(),
            signer: NomisRequestSigner()
        )

        let featureToggleProvider = FeatureToggleProvider(
            networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
            operationQueue: OperationQueue()
        )

        let interactor = WalletMainContainerInteractor(
            accountRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            wallet: wallet,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            deprecatedAccountsCheckService: deprecatedAccountsCheckService,
            applicationHandler: ApplicationHandler(),
            walletConnectService: walletConnect,
            featureToggleService: featureToggleProvider
        )

        let router = WalletMainContainerRouter()

        guard
            let balanceInfoModule = Self.configureBalanceInfoModule(wallet: wallet),
            let assetListModule = Self.configureAssetListModule(metaAccount: wallet),
            let nftModule = Self.configureNftModule(wallet: wallet)
        else {
            return nil
        }

        let viewModelFactory = WalletMainContainerViewModelFactory(
            accountScoreFetcher: accountScoreFetcher,
            settings: SettingsManager.shared
        )
        let presenter = WalletMainContainerPresenter(
            balanceInfoModuleInput: balanceInfoModule.input,
            assetListModuleInput: assetListModule.input,
            nftModuleInput: nftModule.input,
            wallet: wallet,
            viewModelFactory: viewModelFactory,
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
