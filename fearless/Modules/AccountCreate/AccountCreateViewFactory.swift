import Foundation
import IrohaCrypto

final class AccountCreateViewFactory: AccountCreateViewFactoryProtocol {
    static func createView() -> AccountCreateViewProtocol? {
        let view = AccountCreateViewController(nib: R.nib.accountCreateViewController)
        let presenter = AccountCreatePresenter()
        let interactor = AccountCreateInteractor(mnemonicCreator: IRMnemonicCreator())
        let wireframe = AccountCreateWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
