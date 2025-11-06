import UIKit
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFNetwork

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    struct Dependencies {
        let settings: SettingsManager
        let selectedWalletSettings: SelectedWalletSettings
        let chainRegistry: ChainRegistryProtocol
        let applicationConfig: ApplicationConfigProtocol
        let eventCenter: EventCenterProtocol
        let logger: LoggerProtocol?
        let localizationManager: LocalizationManagerProtocol
        let onboardingService: OnboardingServiceProtocol
        let onboardingConfigResolver: OnboardingConfigVersionResolver
        let keychain: KeychainProtocol

        static var `default`: Dependencies {
            Dependencies(
                settings: SettingsManager.shared,
                selectedWalletSettings: SelectedWalletSettings.shared,
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                applicationConfig: ApplicationConfig.shared,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                localizationManager: LocalizationManager.shared,
                onboardingService: OnboardingService(
                    networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
                    operationQueue: OperationQueue()
                ),
                onboardingConfigResolver: OnboardingConfigVersionResolver(userDefaultsStorage: SettingsManager.shared),
                keychain: Keychain()
            )
        }
    }

    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol {
        createPresenter(with: window, dependencies: .default)
    }

    static func createPresenter(with window: UIWindow, dependencies: Dependencies) -> RootPresenterProtocol {
        let wireframe = RootWireframe()
        let startViewHelper = StartViewHelper(
            keystore: dependencies.keychain,
            selectedWalletSettings: dependencies.selectedWalletSettings,
            userDefaultsStorage: dependencies.settings
        )

        let languageMigrator = SelectedLanguageMigrator(
            localizationManager: dependencies.localizationManager
        )

        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: dependencies.keychain,
            settings: dependencies.settings,
            fileManager: FileManager.default
        )

        let substrateDbMigrator = SubstrateStorageMigrator(
            targetVersion: SubstrateStorageParams.modelVersion,
            storeURL: SubstrateStorageParams.storageURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            fileManager: FileManager.default
        )

        let presenter = RootPresenter(
            localizationManager: dependencies.localizationManager,
            startViewHelper: startViewHelper
        )

        _ = AssetManagementMigratorAssembly.createDefaultMigrator()

        let migrators: [Migrating] = [
            languageMigrator,
            dbMigrator,
            substrateDbMigrator
        ]

        let interactor = RootInteractor(
            chainRegistry: dependencies.chainRegistry,
            settings: dependencies.selectedWalletSettings,
            applicationConfig: dependencies.applicationConfig,
            eventCenter: dependencies.eventCenter,
            migrators: migrators,
            logger: dependencies.logger,
            onboardingService: dependencies.onboardingService,
            onboardingConfigResolver: dependencies.onboardingConfigResolver
        )

        let view = RootViewController(
            presenter: presenter,
            localizationManager: dependencies.localizationManager
        )

        presenter.window = window
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view

        interactor.presenter = presenter

        return presenter
    }
}
