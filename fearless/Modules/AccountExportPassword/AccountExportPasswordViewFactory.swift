import Foundation

final class AccountExportPasswordViewFactory: AccountExportPasswordViewFactoryProtocol {
    static func createView() -> AccountExportPasswordViewProtocol? {
        let view = AccountExportPasswordViewController(nib: R.nib.accountExportPasswordViewController)
        let presenter = AccountExportPasswordPresenter()
        let interactor = AccountExportPasswordInteractor()
        let wireframe = AccountExportPasswordWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
