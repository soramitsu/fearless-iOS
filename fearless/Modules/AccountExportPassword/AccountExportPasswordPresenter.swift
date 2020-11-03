import Foundation

final class AccountExportPasswordPresenter {
    weak var view: AccountExportPasswordViewProtocol?
    var wireframe: AccountExportPasswordWireframeProtocol!
    var interactor: AccountExportPasswordInteractorInputProtocol!
}

extension AccountExportPasswordPresenter: AccountExportPasswordPresenterProtocol {
    func setup() {}
}

extension AccountExportPasswordPresenter: AccountExportPasswordInteractorOutputProtocol {}