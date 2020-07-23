import Foundation
import SoraKeystore
import SoraFoundation

final class AccessRestoreViewFactory: AccessRestoreViewFactoryProtocol {
    static func createView() -> AccessRestoreViewProtocol? {

        let localizationManager = LocalizationManager.shared

        let view = AccessRestoreViewController(nib: R.nib.accessRestoreViewController)
        let presenter = AccessRestorePresenter()

        let accountOperationFactory = AccountOperationFactory(keystore: Keychain(),
                                                              settings: SettingsManager.shared)

        let interactor = AccessRestoreInteractor(accountOperationFactory: accountOperationFactory,
                                                 settings: SettingsManager.shared,
                                                 operationManager: OperationManagerFacade.sharedManager)

        let wireframe = AccessRestoreWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
