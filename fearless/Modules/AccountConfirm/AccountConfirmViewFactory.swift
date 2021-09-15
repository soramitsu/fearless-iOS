import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createViewForOnboarding(
        request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForAdding(
        request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = AddAccount.AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForConnection(
        item: ConnectionItem,
        request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository = AccountRepositoryFactory.createRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let interactor = SelectConnection
            .AccountConfirmInteractor(
                connectionItem: item,
                request: request,
                mnemonic: mnemonic,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                settings: SettingsManager.shared,
                operationManager: operationManager,
                eventCenter: EventCenter.shared
            )
        let wireframe = SelectConnection.AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch(
        request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            for: request,
            metadata: metadata
        ) else {
            return nil
        }

        let wireframe = SwitchAccount.AccountConfirmWireframe()
        return createView(for: interactor, wireframe: wireframe)
    }

    private static func createView(
        for interactor: BaseAccountConfirmInteractor,
        wireframe: AccountConfirmWireframeProtocol
    ) -> AccountConfirmViewProtocol? {
        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.skipButtonTitle = LocalizableResource { locale in
            R.string.localizable.confirmationSkipAction(preferredLanguages: locale.rLanguages)
        }

        let presenter = AccountConfirmPresenter()

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

    private static func createAccountConfirmInteractor(
        for request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()
        let settings = SettingsManager.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository = AccountRepositoryFactory.createRepository()

        let interactor = AccountConfirmInteractor(
            request: request,
            mnemonic: mnemonic,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationManager: OperationManagerFacade.sharedManager
        )

        return interactor
    }

    private static func createAddAccountConfirmInteractor(
        for request: AccountCreationRequest,
        metadata: AccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository = AccountRepositoryFactory.createRepository()

        let interactor = AddAccount
            .AccountConfirmInteractor(
                request: request,
                mnemonic: mnemonic,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SettingsManager.shared,
                eventCenter: EventCenter.shared
            )

        return interactor
    }
}
