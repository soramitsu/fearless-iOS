import UIKit
import SoraFoundation
import SoraKeystore
import SSFQRService

final class GetPreinstalledWalletAssembly {
    static func configureModuleForExistingUser() -> GetPreinstalledWalletModuleCreationResult? {
        let router = ExistingUserGetPreinstalledWalletRouter()
        return configureModule(router: router)
    }

    static func configureModuleForNewUser() -> GetPreinstalledWalletModuleCreationResult? {
        let router = NewUserGetPreinstalledWalletRouter()
        return configureModule(router: router)
    }

    private static func configureModule(router: GetPreinstalledWalletRouterInput) -> GetPreinstalledWalletModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let qrScanService = QRCaptureServiceFactory().createService(
            delegate: nil,
            delegateQueue: nil
        )

        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let qrService = QRServiceDefault(matchers: [QRPreinstalledWalletMatcher()])
        let interactor = GetPreinstalledWalletInteractor(
            qrService: qrService,
            qrScanService: qrScanService,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            keystoreImportService: keystoreImportService,
            defaultSource: .mnemonic,
            settings: settings,
            eventCenter: EventCenter.shared
        )

        let presenter = GetPreinstalledWalletPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = GetPreinstalledWalletViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
