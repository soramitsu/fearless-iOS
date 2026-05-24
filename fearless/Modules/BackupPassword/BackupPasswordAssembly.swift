import UIKit
import FearlessFoundation
import SSFCloudStorage
import FearlessSecureStorage

final class BackupPasswordAssembly {
    struct Dependencies {
        var keystoreImportServiceProvider: () -> KeystoreImportServiceProtocol?
        var localizationManager: LocalizationManagerProtocol
        var logger: LoggerProtocol

        static var live: Dependencies {
            Dependencies(
                keystoreImportServiceProvider: URLHandlingDependencies.keystoreImportService,
                localizationManager: LocalizationManager.shared,
                logger: Logger.shared
            )
        }
    }

    static func configureModule(
        backupAccounts: [BackupAccount],
        dependencies: Dependencies = .live
    ) -> BackupPasswordModuleCreationResult? {
        guard let keystoreImportService = dependencies.keystoreImportServiceProvider()
        else {
            dependencies.logger.error("Missing required keystore import service")
            return nil
        }
        let localizationManager = dependencies.localizationManager

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = BackupPasswordInteractor(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: settings,
            keystoreImportService: keystoreImportService,
            eventCenter: EventCenter.shared,
            defaultSource: .mnemonic
        )
        let router = BackupPasswordRouter()

        let presenter = BackupPasswordPresenter(
            backupAccounts: backupAccounts,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            logger: dependencies.logger
        )

        let view = BackupPasswordViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        let cloudStorage = CloudStorageService(uiDelegate: view)
        interactor.cloudStorage = cloudStorage

        return (view, presenter)
    }
}
