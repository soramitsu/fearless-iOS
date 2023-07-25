import UIKit
import SoraFoundation
import SSFCloudStorage
import SoraKeystore

final class BackupPasswordAssembly {
    static func configureModule(
        backupAccounts: [BackupAccount]
    ) -> BackupPasswordModuleCreationResult? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }
        let localizationManager = LocalizationManager.shared

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
            logger: Logger.shared
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
