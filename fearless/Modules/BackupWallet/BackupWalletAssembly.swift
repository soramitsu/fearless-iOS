import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFCloudStorage

final class BackupWalletAssembly {
    static func configureModule(
        wallet: MetaAccountModel
    ) -> BackupWalletModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            logger: logger
        )

        let interactor = BackupWalletInteractor(
            wallet: wallet,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationManager: OperationManagerFacade.sharedManager
        )
        let router = BackupWalletRouter()

        let presenter = BackupWalletPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            logger: logger,
            localizationManager: localizationManager
        )

        let view = BackupWalletViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        let cloudStorage = CloudStorageService(uiDelegate: view)
        interactor.cloudStorage = cloudStorage

        return (view, presenter)
    }
}
