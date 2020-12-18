import UIKit
import CommonWallet

protocol PurchaseViewProtocol: ControllerBackedProtocol {}

protocol PurchasePresenterProtocol: class {
    func setup()
}

protocol PurchaseInteractorInputProtocol: class {
    func setup()
}

protocol PurchaseInteractorOutputProtocol: class {
    func didCompletePurchase()
}

protocol PurchaseWireframeProtocol: class {
    func complete(from view: PurchaseViewProtocol?)
}

protocol PurchaseViewFactoryProtocol: class {
    static func createView(for action: PurchaseAction,
                           commandFactory: WalletCommandFactoryProtocol) -> PurchaseViewProtocol?
}
