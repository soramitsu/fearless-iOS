import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createView(username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let operationFactory = AccountOperationFactory(keystore: Keychain(),
                                                       settings: SettingsManager.shared)

        let interactor = AccountCreateInteractor(accountOperationFactory: operationFactory,
                                                 mnemonicCreator: IRMnemonicCreator(),
                                                 operationManager: OperationManagerFacade.sharedManager)
        let wireframe = AccountCreateWireframe()

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
