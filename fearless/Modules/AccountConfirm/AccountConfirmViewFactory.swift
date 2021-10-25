import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createViewForOnboarding(
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
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
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
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

    static func createViewForSwitch(
        request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
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
        for request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = AccountConfirmInteractor(
            request: request,
            mnemonic: mnemonic,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )

        return interactor
    }

    private static func createAddAccountConfirmInteractor(
        for request: MetaAccountCreationRequest,
        metadata: MetaAccountCreationMetadata
    ) -> BaseAccountConfirmInteractor? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " "))
        else {
            return nil
        }

        let keychain = Keychain()

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

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
