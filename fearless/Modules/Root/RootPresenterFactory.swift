import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe()
        let settings = SettingsManager.shared
        let keychain = Keychain()

        let networkConnectionsMigrator = NetworkConnectionsMigrator(settings: settings)
        let inconsistentStateMigrator = InconsistentStateMigrator(
            settings: settings,
            keychain: keychain
        )

        let interactor = RootInteractor(
            settings: settings,
            keystore: keychain,
            applicationConfig: ApplicationConfig.shared,
            eventCenter: EventCenter.shared,
            migrators: [inconsistentStateMigrator, networkConnectionsMigrator],
            logger: Logger.shared
        )

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
