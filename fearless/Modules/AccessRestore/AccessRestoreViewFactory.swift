import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto

final class AccessRestoreViewFactory: AccessRestoreViewFactoryProtocol {
    static func createView() -> AccessRestoreViewProtocol? {

        let localizationManager = LocalizationManager.shared

        let view = AccessRestoreViewController(nib: R.nib.accessRestoreViewController)
        let presenter = AccessRestorePresenter()

        let accountOperationFactory = AccountOperationFactory(keystore: Keychain(),
                                                              settings: SettingsManager.shared)

        let mnemonicCreator = IRMnemonicCreator()

        let interactor = AccessRestoreInteractor(accountOperationFactory: accountOperationFactory,
                                                 mnemonicCreator: mnemonicCreator,
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
