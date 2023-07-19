import UIKit
import SoraFoundation
import SSFCloudStorage
import SoraKeystore

enum BackupCreatePasswordFlow {
    case createWallet(MetaAccountImportMnemonicRequest)
    case backupWallet(wallet: MetaAccountModel, request: MetaAccountImportMnemonicRequest)

    var request: MetaAccountImportMnemonicRequest {
        switch self {
        case let .createWallet(request):
            return request
        case let .backupWallet(_, request):
            return request
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
        let request = flow.request

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = BackupCreatePasswordInteractor(
            createPasswordFlow: flow,
            flow: .wallet(request),
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )

        let router = BackupCreatePasswordRouter()

        let presenter = BackupCreatePasswordPresenter(
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
