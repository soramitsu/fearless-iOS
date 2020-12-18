import UIKit
import SoraKeystore
import SoraFoundation

final class RootPresenterFactory: RootPresenterFactoryProtocol {
    static func createPresenter(with view: UIWindow) -> RootPresenterProtocol {
        let presenter = RootPresenter()
        let wireframe = RootWireframe()

        let interactor = RootInteractor(settings: SettingsManager.shared,
                                        keystore: Keychain(),
                                        applicationConfig: ApplicationConfig.shared,
                                        eventCenter: EventCenter.shared)

        presenter.view = view
        presenter.wireframe = wireframe
        presenter.interactor = interactor

        interactor.presenter = presenter

        return presenter
    }
}
