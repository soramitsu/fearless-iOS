import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import IrohaCrypto

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createViewForOnboarding() -> AccountImportViewProtocol? {
        guard let interactor = createAccountImportInteractor() else {
            return nil
        }

        let wireframe = AccountImportWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForAdding() -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor() else {
            return nil
        }

        let wireframe = AddAccount.AccountImportWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForConnection(item: ConnectionItem) -> AccountImportViewProtocol? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository = AccountRepositoryFactory.createRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let interactor = SelectConnection
            .AccountImportInteractor(
                connectionItem: item,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: operationManager,
                settings: SettingsManager.shared,
                keystoreImportService: keystoreImportService,
                eventCenter: EventCenter.shared
            )

        let wireframe = SelectConnection.AccountImportWireframe(connection: item)

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch() -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor() else {
            return nil
        }

        let wireframe = SwitchAccount.AccountImportWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    private static func createView(
        for interactor: BaseAccountImportInteractor,
        wireframe: AccountImportWireframeProtocol
    ) -> AccountImportViewProtocol? {
        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()

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

    private static func createAccountImportInteractor() -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SettingsManager.shared
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository = AccountRepositoryFactory.createRepository()

        let interactor = AccountImportInteractor(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: settings,
            keystoreImportService: keystoreImportService
        )

        return interactor
    }

    private static func createAddAccountImportInteractor() -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactory = AccountOperationFactory(keystore: keystore)

        let accountRepository = AccountRepositoryFactory.createRepository()

        let interactor = AddAccount
            .AccountImportInteractor(
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SettingsManager.shared,
                keystoreImportService: keystoreImportService,
                eventCenter: EventCenter.shared
            )

        return interactor
    }
}
