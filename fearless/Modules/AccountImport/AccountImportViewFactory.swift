import Foundation

final class AccountImportViewFactory: AccountImportViewFactoryProtocol {
    static func createView() -> AccountImportViewProtocol? {
        let view = AccountImportViewController(nib: R.nib.accountImportViewController)
        let presenter = AccountImportPresenter()
        let interactor = AccountImportInteractor()
        let wireframe = AccountImportWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
