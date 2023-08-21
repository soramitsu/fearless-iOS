import UIKit
import SoraFoundation
import SSFCloudStorage
import SoraKeystore

enum BackupCreatePasswordFlow {
    case createWallet(MetaAccountImportMnemonicRequest)
    case backupWallet(flow: ExportFlow, options: [ExportOption])

    enum RequestType {
        case mnemonic(MetaAccountImportMnemonicRequest)
        case jsons([RestoreJson])
        case seeds([ExportSeedData])
    }

    var mnemonicRequest: MetaAccountImportMnemonicRequest? {
        switch self {
        case let .createWallet(metaAccountImportMnemonicRequest):
            return metaAccountImportMnemonicRequest
        case .backupWallet:
            return nil
        }
    }
}

enum BackupCreatePasswordAssembly {
    static func configureModule(
        with flow: BackupCreatePasswordFlow,
        moduleOutput: BackupCreatePasswordModuleOutput? = nil
    ) -> BackupCreatePasswordModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let keystore = Keychain()
        let interactor = BackupCreatePasswordInteractor(
            createPasswordFlow: flow,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            secretManager: KeychainManager.shared,
            keystore: keystore,
            exportJsonWrapper: KeystoreExportWrapper(keystore: keystore)
        )

        let router = BackupCreatePasswordRouter()

        let presenter = BackupCreatePasswordPresenter(
            logger: Logger.shared,
            flow: flow,
            moduleOutput: moduleOutput,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = BackupCreatePasswordViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        let cloudStorage = CloudStorageService(
            uiDelegate: view
        )
        interactor.cloudStorage = cloudStorage

        return (view, presenter)
    }
}
