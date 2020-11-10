import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import IrohaCrypto

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createViewForOnboarding() -> AccountImportViewProtocol? {
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

    static func createViewForAdding() -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountImportInteractor(accountOperationFactory: accountOperationFactory,
                                                    accountRepository: AnyDataProviderRepository(accountRepository),
                                                    operationManager: OperationManagerFacade.sharedManager,
                                                    settings: SettingsManager.shared,
                                                    keystoreImportService: keystoreImportService,
                                                    eventCenter: EventCenter.shared)

        let wireframe = AddImportedWireframe()

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

    static func createViewForConnection(item: ConnectionItem) -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService() else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem>
            = UserDataStorageFacade.shared.createRepository()

        let anyRepository = AnyDataProviderRepository(accountRepository)
        let operationManager = OperationManagerFacade.sharedManager
        let interactor = ConnectionAccountImportedInteractor(connectionItem: item,
                                                             accountOperationFactory: accountOperationFactory,
                                                             accountRepository: anyRepository,
                                                             operationManager: operationManager,
                                                             settings: SettingsManager.shared,
                                                             keystoreImportService: keystoreImportService,
                                                             eventCenter: EventCenter.shared)

        let wireframe = ConnectionAccountImportedWireframe(connection: item)

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
