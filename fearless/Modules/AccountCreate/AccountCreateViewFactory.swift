import Foundation
import IrohaCrypto
import SoraFoundation

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

        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
