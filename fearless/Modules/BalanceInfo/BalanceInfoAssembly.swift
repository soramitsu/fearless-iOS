import UIKit
import SoraFoundation
import RobinHood
import SSFUtils

enum BalanceInfoType {
    case wallet(wallet: MetaAccountModel)
    case chainAsset(wallet: MetaAccountModel, chainAsset: ChainAsset)
}

enum BalanceInfoAssembly {
    static func configureModule(with type: BalanceInfoType) -> BalanceInfoModuleCreationResult? {
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

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: eventCenter,
            logger: logger
        )

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
            localizationManager: localizationManager
        )

        let view = BalanceInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
