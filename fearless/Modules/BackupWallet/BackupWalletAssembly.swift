import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFCloudStorage
import SSFNetwork

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
        let accountScoreFetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerDefault(),
            signer: NomisRequestSigner()
        )

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
        // Google Sign-In raises an Objective-C exception for missing configuration.
        // Keep local exports available without constructing that service in keyless builds.
        if (try? GoogleDriveBackupOAuthConfiguration(info: Bundle.main.infoDictionary ?? [:])) != nil {
            interactor.cloudStorage = CloudStorageService(uiDelegate: view)
        }

        return (view, presenter)
    }
}
