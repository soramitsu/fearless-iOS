import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createView() -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()

        let keystore = Keychain()
        let settings = SettingsManager.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                 accountRepository: AnyDataProviderRepository(accountRepository),
                                                 operationManager: OperationManagerFacade.sharedManager,
                                                 settings: settings,
                                                 keystoreImportService: keystoreImportService)

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
