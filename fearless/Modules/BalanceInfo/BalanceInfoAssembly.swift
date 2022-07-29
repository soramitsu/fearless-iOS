import UIKit
import SoraFoundation
import RobinHood

enum BalanceInfoType {
    case wallet(metaAccount: MetaAccountModel)
    case chainAsset(metaAccount: MetaAccountModel, chainAsset: ChainAsset)
}

enum BalanceInfoAssembly {
    static func configureModule(with type: BalanceInfoType) -> BalanceInfoModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

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

        let interactor = BalanceInfoInteractor(
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter
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
            localizationManager: localizationManager
        )

        let view = BalanceInfoViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
