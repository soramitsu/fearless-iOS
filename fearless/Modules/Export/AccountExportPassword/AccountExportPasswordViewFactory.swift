import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood

final class AccountExportPasswordViewFactory: AccountExportPasswordViewFactoryProtocol {
    static func createView(with address: String) -> AccountExportPasswordViewProtocol? {
        let localizationManager = LocalizationManager.shared

        let view = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = AccountExportPasswordPresenter(
            address: address,
            localizationManager: localizationManager
        )

        let exportJsonWrapper = KeystoreExportWrapper(keystore: Keychain())

        let facade = UserDataStorageFacade.shared
        let repository: CoreDataRepository<AccountItem, CDAccountItem> = facade.createRepository()

        let interactor = AccountExportPasswordInteractor(
            exportJsonWrapper: exportJsonWrapper,
            repository: AnyDataProviderRepository(repository),
            operationManager: OperationManagerFacade.sharedManager
        )
        let wireframe = AccountExportPasswordWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = localizationManager

        return view
    }
}
