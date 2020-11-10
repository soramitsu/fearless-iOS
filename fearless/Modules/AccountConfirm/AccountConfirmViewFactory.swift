import Foundation
import SoraKeystore
import SoraFoundation
import IrohaCrypto
import RobinHood

final class AccountConfirmViewFactory: AccountConfirmViewFactoryProtocol {
    static func createViewForOnboarding(request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }

        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.skipButtonTitle = LocalizableResource { locale in
            R.string.localizable.confirmationSkipAction(preferredLanguages: locale.rLanguages)
        }

        let presenter = AccountConfirmPresenter()

        let keychain = Keychain()
        let settings = SettingsManager.shared

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AccountConfirmInteractor(request: request,
                                                  mnemonic: mnemonic,
                                                  accountOperationFactory: accountOperationFactory,
                                                  accountRepository: AnyDataProviderRepository(accountRepository),
                                                  settings: settings,
                                                  operationManager: OperationManagerFacade.sharedManager)
        let wireframe = AccountConfirmWireframe()

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

    static func createViewForAdding(request: AccountCreationRequest,
                                    metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }

        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.skipButtonTitle = LocalizableResource { locale in
            R.string.localizable.confirmationSkipAction(preferredLanguages: locale.rLanguages)
        }

        let presenter = AccountConfirmPresenter()

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AddAccountConfirmInteractor(request: request,
                                                     mnemonic: mnemonic,
                                                     accountOperationFactory: accountOperationFactory,
                                                     accountRepository: AnyDataProviderRepository(accountRepository),
                                                     operationManager: OperationManagerFacade.sharedManager,
                                                     settings: SettingsManager.shared,
                                                     eventCenter: EventCenter.shared)
        let wireframe = AddConfirmationWireframe()

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

    static func createViewForConnection(item: ConnectionItem,
                                        request: AccountCreationRequest,
                                        metadata: AccountCreationMetadata) -> AccountConfirmViewProtocol? {
        guard let mnemonic = try? IRMnemonicCreator()
            .mnemonic(fromList: metadata.mnemonic.joined(separator: " ")) else {
            return nil
        }

        let view = AccountConfirmViewController(nib: R.nib.accountConfirmViewController)
        view.skipButtonTitle = LocalizableResource { locale in
            R.string.localizable.confirmationSkipAction(preferredLanguages: locale.rLanguages)
        }

        let presenter = AccountConfirmPresenter()

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let anyRepository = AnyDataProviderRepository(accountRepository)
        let interactor = ConnectionAccountConfirmInteractor(connectionItem: item,
                                                             request: request,
                                                             mnemonic: mnemonic,
                                                             accountOperationFactory: accountOperationFactory,
                                                             accountRepository: anyRepository,
                                                             settings: SettingsManager.shared,
                                                             operationManager: operationManager,
                                                             eventCenter: EventCenter.shared)
        let wireframe = ConnectionAccountConfirmationWireframe()

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
