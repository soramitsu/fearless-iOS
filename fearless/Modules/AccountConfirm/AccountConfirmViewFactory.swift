import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createViewForOnboarding(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAccountConfirmInteractor(
            flow: flow
        ) else {
            return nil
        }

        let wireframe = AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForAdding(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            flow: flow
        ) else {
            return nil
        }

        let wireframe = AddAccount.AccountConfirmWireframe()

        return createView(for: interactor, wireframe: wireframe)
    }

    static func createViewForSwitch(
        flow: AccountConfirmFlow
    ) -> AccountConfirmViewProtocol? {
        guard let interactor = createAddAccountConfirmInteractor(
            flow: flow
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
        flow: AccountConfirmFlow
    ) -> BaseAccountConfirmInteractor? {
        let keychain = Keychain()
        let settings = SelectedWalletSettings.shared

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = AccountConfirmInteractor(
            flow: flow,
            accountOperationFactory: accountOperationFactory,
            accountRepository: accountRepository,
            settings: settings,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )

        return interactor
    }

    private static func createAddAccountConfirmInteractor(
        flow: AccountConfirmFlow
    ) -> BaseAccountConfirmInteractor? {
        let keychain = Keychain()

        let accountOperationFactory = MetaAccountOperationFactory(keystore: keychain)
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let interactor = AddAccount
            .AccountConfirmInteractor(
                flow: flow,
                accountOperationFactory: accountOperationFactory,
                accountRepository: accountRepository,
                operationManager: OperationManagerFacade.sharedManager,
                settings: SelectedWalletSettings.shared,
                eventCenter: EventCenter.shared
            )

        return interactor
    }
}
