import Foundation
import SoraFoundation
import CommonWallet

final class PurchaseViewFactory: PurchaseViewFactoryProtocol {
    static func createView(for action: PurchaseAction,
                           commandFactory: WalletCommandFactoryProtocol) -> PurchaseViewProtocol? {
        let view = PurchaseViewController(url: action.url)

        let presenter = PurchasePresenter(action: action)
        let interactor = PurchaseInteractor(eventCenter: EventCenter.shared)
        let wireframe = PurchaseWireframe(localizationManager: LocalizationManager.shared,
                                          commandFactory: commandFactory)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
