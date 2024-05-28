import UIKit
import SoraKeystore
import SoraFoundation
import RobinHood
import SSFNetwork

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol {
        let wireframe = RootWireframe()
        let settings = SettingsManager.shared
        let keychain = Keychain()
        let startViewHelper = StartViewHelper(
            keystore: keychain,
            selectedWalletSettings: SelectedWalletSettings.shared,
            userDefaultsStorage: SettingsManager.shared
        )

        let languageMigrator = SelectedLanguageMigrator(
            localizationManager: LocalizationManager.shared
        )

        let dbMigrator = UserStorageMigrator(
            targetVersion: UserStorageParams.modelVersion,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )

        let substrateDbMigrator = SubstrateStorageMigrator(
            targetVersion: SubstrateStorageParams.modelVersion,
            storeURL: SubstrateStorageParams.storageURL,
            modelDirectory: SubstrateStorageParams.modelDirectory,
            fileManager: FileManager.default
        )

        let presenter = RootPresenter(
            localizationManager: LocalizationManager.shared,
            startViewHelper: startViewHelper
        )

        let assetManagementMigrator = AssetManagementMigratorAssembly.createDefaultMigrator()

        let migrators: [Migrating] = [
            languageMigrator,
            dbMigrator,
            substrateDbMigrator,
            assetManagementMigrator
        ]

        let service = OnboardingService(
            networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
            operationQueue: OperationQueue()
        )

        let resolver = OnboardingConfigVersionResolver(userDefaultsStorage: SettingsManager.shared)

        let interactor = RootInteractor(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            settings: SelectedWalletSettings.shared,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: EventCenter.shared,
            migrators: migrators,
            logger: Logger.shared,
            onboardingService: service,
            onboardingConfigResolver: resolver
        )

        let view = RootViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.window = window
        presenter.wireframe = wireframe
        presenter.interactor = interactor
        presenter.view = view

        interactor.presenter = presenter

        return presenter
    }
}
