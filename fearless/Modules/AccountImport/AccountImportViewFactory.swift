import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import IrohaCrypto

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createViewForOnboarding(
        defaultSource: AccountImportSource = .mnemonic,
        flow: AccountImportFlow = .wallet(step: .substrate)
    ) -> AccountImportViewProtocol? {
        guard let interactor = createAccountImportInteractor(defaultSource: defaultSource) else {
            return nil
        }

        let wireframe = AccountImportWireframe()
        return createView(for: interactor, wireframe: wireframe, flow: flow)
    }

    static func createViewForAdding(
        defaultSource: AccountImportSource,
        _ flow: AccountImportFlow = .wallet(step: .substrate)
    ) -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor(defaultSource: defaultSource) else {
            return nil
        }

        let wireframe = AddAccount.AccountImportWireframe()

        return createView(for: interactor, wireframe: wireframe, flow: flow)
    }

    static func createViewForSwitch() -> AccountImportViewProtocol? {
        guard let interactor = createAddAccountImportInteractor(defaultSource: .mnemonic) else {
            return nil
        }

        let wireframe = SwitchAccount.AccountImportWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    private static func createView(
        for interactor: BaseAccountImportInteractor,
        wireframe: AccountImportWireframeProtocol,
        flow: AccountImportFlow = .wallet(step: .substrate)
    ) -> AccountImportViewProtocol? {
        let presenter = AccountImportPresenter(
            wireframe: wireframe,
            interactor: interactor,
            flow: flow
        )
        let view = AccountImportViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }

    private static func createAccountImportInteractor(
        defaultSource: AccountImportSource
    ) -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = EventCenter.shared

        let interactor = AccountImportInteractor(
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            operationManager: OperationManagerFacade.sharedManager,
            settings: settings,
            keystoreImportService: keystoreImportService,
            eventCenter: eventCenter,
            defaultSource: defaultSource
        )

        return interactor
    }

    private static func createAddAccountImportInteractor(
        defaultSource: AccountImportSource
    ) -> BaseAccountImportInteractor? {
        guard let keystoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Missing required keystore import service")
            return nil
        }

        let keystore = Keychain()
        let accountOperationFactory = MetaAccountOperationFactory(keystore: keystore)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let eventCenter = EventCenter.shared

        let interactor = AddAccount
            .AccountImportInteractor(
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SelectedWalletSettings.shared,
                keystoreImportService: keystoreImportService,
                eventCenter: eventCenter,
                defaultSource: defaultSource
            )

        return interactor
    }
}
