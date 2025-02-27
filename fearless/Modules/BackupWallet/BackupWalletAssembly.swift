import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFNetwork
import SSFModels

final class BackupWalletAssembly {
    static func configureModule(
        wallet: MetaAccountModel
    ) -> BackupWalletModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared
        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = BackupWalletInteractor(
            wallet: wallet,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            availableExportOptionsProvider: AvailableExportOptionsProvider(),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationManager: OperationManagerFacade.sharedManager
        )
        let router = BackupWalletRouter()
        let accountScoreFetcher = AccountScoreRepository(fetcher: ServiceAssembly.shared.nomisAccountScoreFetcher)

        let viewModelFactory = BackupWalletViewModelFactory(accountScoreFetcher: accountScoreFetcher, settings: SettingsManager.shared)
        let presenter = BackupWalletPresenter(
            wallet: wallet,
            interactor: interactor,
            router: router,
            logger: logger,
            localizationManager: localizationManager,
            viewModelFactory: viewModelFactory
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
