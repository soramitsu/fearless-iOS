import UIKit
import SoraFoundation
import RobinHood
import SSFUtils
import SSFModels

enum BalanceInfoType {
    case wallet(wallet: MetaAccountModel)
    case chainAsset(wallet: MetaAccountModel, chainAsset: ChainAsset)

    var wallet: MetaAccountModel {
        switch self {
        case let .wallet(wallet):
            return wallet
        case let .chainAsset(wallet, _):
            return wallet
        }
    }
}

enum BalanceInfoAssembly {
    static func configureModule(with type: BalanceInfoType) -> BalanceInfoModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else { return nil }
        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.sharedManager

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let interactor = BalanceInfoInteractor(
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            operationManager: operationManager,
            storageRequestFactory: storageRequestFactory
        )

        let router = BalanceInfoRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let balanceInfoViewModelFactory = BalanceInfoViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let presenter = BalanceInfoPresenter(
            balanceInfoType: type,
            balanceInfoViewModelFactoryProtocol: balanceInfoViewModelFactory,
            interactor: interactor,
            router: router,
            logger: logger,
            localizationManager: localizationManager,
            eventCenter: EventCenter.shared
        )

        let view = BalanceInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
