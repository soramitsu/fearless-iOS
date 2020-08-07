import Foundation

final class AccountImportPresenter {
    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!
}

extension AccountImportPresenter: AccountImportPresenterProtocol {
    func setup() {}
}

extension AccountImportPresenter: AccountImportInteractorOutputProtocol {}