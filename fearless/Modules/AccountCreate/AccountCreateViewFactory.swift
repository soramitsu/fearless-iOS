import Foundation
import IrohaCrypto
import SoraFoundation
import SoraKeystore

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createViewForOnboarding(username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        let wireframe = AccountCreateWireframe()

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

    static func createViewForAdding(username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        let wireframe = AddCreationWireframe()

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
                                        username: String) -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter(username: username)

        let interactor = ConnectionAccountCreationInteractor(mnemonicCreator: IRMnemonicCreator(),
                                                             connection: item)

        let wireframe = ConnectionAccountCreationWireframe(connectionItem: item)

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
