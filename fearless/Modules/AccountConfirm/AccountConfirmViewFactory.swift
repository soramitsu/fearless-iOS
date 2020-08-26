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
        let presenter = AccountConfirmPresenter()

        let keychain = Keychain()

        let accountOperationFactory = AccountOperationFactory(keystore: keychain)
        let accountRepository: CoreDataRepository<AccountItem, CDAccountItem> =
            UserDataStorageFacade.shared.createRepository()

        let interactor = AddCreatedInteractor(request: request,
                                              mnemonic: mnemonic,
                                              accountOperationFactory: accountOperationFactory,
                                              accountRepository: AnyDataProviderRepository(accountRepository),
                                              operationManager: OperationManagerFacade.sharedManager)
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
}
