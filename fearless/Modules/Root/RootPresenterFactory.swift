import UIKit
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFNetwork

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    struct Dependencies {
        let settings: SettingsManager
        let selectedWalletSettingsProvider: () -> SelectedWalletSettings
        let chainRegistryProvider: () -> ChainRegistryProtocol
        let storagePreflightProvider: RootStoragePreflightProvider
        let applicationConfig: ApplicationConfigProtocol
        let eventCenter: EventCenterProtocol
        let logger: LoggerProtocol?
        let localizationManager: LocalizationManagerProtocol
        let onboardingService: OnboardingServiceProtocol
        let onboardingConfigResolver: OnboardingConfigVersionResolver
        let keystore: KeystoreProtocol
        let protectedDataAvailabilityMonitor:
            RootProtectedDataAvailabilityMonitoring

        static var `default`: Dependencies {
            Dependencies(
                settings: SettingsManager.shared,
                selectedWalletSettingsProvider: {
                    SelectedWalletSettings.shared
                },
                chainRegistryProvider: {
                    ChainRegistryFacade.sharedRegistry
                },
                storagePreflightProvider: {
                    RootCoreDataStoragePreflight(
                        databaseService: SubstrateDataStorageFacade.shared.databaseService
                    )
                },
                applicationConfig: ApplicationConfig.shared,
                eventCenter: EventCenter.shared,
                logger: Logger.shared,
                localizationManager: LocalizationManager.shared,
                onboardingService: OnboardingService(
                    networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
                    operationQueue: OperationQueue()
                ),
                onboardingConfigResolver: OnboardingConfigVersionResolver(userDefaultsStorage: SettingsManager.shared),
                keystore: Keychain(),
                protectedDataAvailabilityMonitor:
                RootUIApplicationProtectedDataAvailabilityMonitor()
            )
        }
    }

    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol {
        createPresenter(with: window, dependencies: .default)
    }

    static func createPresenter(with window: UIWindow, dependencies: Dependencies) -> RootPresenterProtocol {
        let wireframe = RootWireframe()
        let startViewHelper = StartViewHelper(
            keystore: dependencies.keystore,
            selectedWalletSettingsProvider:
            dependencies.selectedWalletSettingsProvider,
            userDefaultsStorage: dependencies.settings
        )

        let languageMigrator = SelectedLanguageMigrator(
            localizationManager: dependencies.localizationManager
        )

        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: dependencies.keystore,
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

        let migrationSteps = [
            RootSetupMigrationStep(
                phase: .languageMigration,
                migrator: languageMigrator
            ),
            RootSetupMigrationStep(
                phase: .userStorageMigration,
                migrator: dbMigrator
            ),
            RootSetupMigrationStep(
                phase: .substrateMigration,
                migrator: substrateDbMigrator
            )
        ]

        let interactor = RootInteractor(
            chainRegistryProvider: dependencies.chainRegistryProvider,
            storagePreflightProvider: dependencies.storagePreflightProvider,
            settingsProvider: dependencies.selectedWalletSettingsProvider,
            applicationConfig: dependencies.applicationConfig,
            eventCenter: dependencies.eventCenter,
            migrationSteps: migrationSteps,
            logger: dependencies.logger,
            onboardingService: dependencies.onboardingService,
            onboardingConfigResolver: dependencies.onboardingConfigResolver,
            protectedDataAvailabilityMonitor:
            dependencies.protectedDataAvailabilityMonitor
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
