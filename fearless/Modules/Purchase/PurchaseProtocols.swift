import UIKit
import CommonWallet

protocol PurchaseViewProtocol: ControllerBackedProtocol {}

protocol PurchasePresenterProtocol: AnyObject {
    func setup()
}

protocol PurchaseInteractorInputProtocol: AnyObject {
    func setup()
}

protocol PurchaseInteractorOutputProtocol: AnyObject {
    func didCompletePurchase()
}

protocol PurchaseWireframeProtocol: AnyObject {
    func complete(from view: PurchaseViewProtocol?)
}

protocol PurchaseViewFactoryProtocol: AnyObject {
    static func createView(
        for action: PurchaseAction,
        commandFactory: WalletCommandFactoryProtocol
    ) -> PurchaseViewProtocol?
}
