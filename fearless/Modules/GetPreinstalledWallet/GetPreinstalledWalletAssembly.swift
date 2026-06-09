import UIKit
import FearlessFoundation
import FearlessSecureStorage
import SSFQRService

final class GetPreinstalledWalletAssembly {
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

    static func configureModuleForExistingUser(
        dependencies: Dependencies = .live
    ) -> GetPreinstalledWalletModuleCreationResult? {
        let router = ExistingUserGetPreinstalledWalletRouter()
        return configureModule(router: router, dependencies: dependencies)
    }

    static func configureModuleForNewUser(
        dependencies: Dependencies = .live
    ) -> GetPreinstalledWalletModuleCreationResult? {
        let router = NewUserGetPreinstalledWalletRouter()
        return configureModule(router: router, dependencies: dependencies)
    }

    private static func configureModule(
        router: GetPreinstalledWalletRouterInput,
        dependencies: Dependencies
    ) -> GetPreinstalledWalletModuleCreationResult? {
        guard let keystoreImportService = dependencies.keystoreImportServiceProvider()
        else {
            dependencies.logger.error("Missing required keystore import service")
            return nil
        }

        let localizationManager = dependencies.localizationManager

        let qrScanService = QRCaptureServiceFactory().createService(
            delegate: nil,
            delegateQueue: nil
        )

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let qrService = QRServiceDefault()
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
            logger: dependencies.logger
        )

        let view = GetPreinstalledWalletViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
