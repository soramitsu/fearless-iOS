import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with window: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter(localizationManager: LocalizationManager.shared)
        let wireframe = RootWireframe()
        let settings = SettingsManager.shared
        let keychain = Keychain()

        let languageMigrator = SelectedLanguageMigrator(
            localizationManager: LocalizationManager.shared
        )
        let networkConnectionsMigrator = NetworkConnectionsMigrator(settings: settings)

        let dbMigrator = UserStorageMigrator(
            targetVersion: .version3,
            storeURL: UserStorageParams.storageURL,
            modelDirectory: UserStorageParams.modelDirectory,
            keystore: keychain,
            settings: settings,
            fileManager: FileManager.default
        )

        let jsonDataProviderFactory = JsonDataProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            useCache: false
        )

        let appVersionObserver = AppVersionObserver(
            jsonLocalSubscriptionFactory: jsonDataProviderFactory,
            currentAppVersion: AppVersion.stringValue
        )

        let interactor = RootInteractor(
            settings: SelectedWalletSettings.shared,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: EventCenter.shared,
            migrators: [languageMigrator, networkConnectionsMigrator, dbMigrator],
            logger: Logger.shared,
            appVersionObserver: appVersionObserver,
            applicationHandler: ApplicationHandler()
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
