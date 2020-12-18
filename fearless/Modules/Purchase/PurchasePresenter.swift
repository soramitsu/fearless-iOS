import Foundation

final class PurchasePresenter {
    weak var view: PurchaseViewProtocol?
    var wireframe: PurchaseWireframeProtocol!
    var interactor: PurchaseInteractorInputProtocol!

    let action: PurchaseAction

    init(action: PurchaseAction) {
        self.action = action
    }
}

extension PurchasePresenter: PurchasePresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension PurchasePresenter: PurchaseInteractorOutputProtocol {
    func didCompletePurchase() {
        wireframe.complete(from: view)
    }
}
