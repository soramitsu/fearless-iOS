import Foundation
import SoraKeystore
import SoraFoundation

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createView() -> AccountConfirmViewProtocol? {
        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        let presenter = AccountConfirmPresenter()

        let keychain = Keychain()
        let settings = SettingsManager.shared

        let interactor = AccountConfirmInteractor(keychain: keychain, settings: settings)
        let wireframe = AccountConfirmWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
