import Foundation
import SoraFoundation
import SoraKeystore

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createView() -> AccountImportViewProtocol? {
        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()

        let keystore = Keychain()
        let settings = SettingsManager.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore,
                                                              settings: settings)

        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings)

        let wireframe = AccountImportWireframe()

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
