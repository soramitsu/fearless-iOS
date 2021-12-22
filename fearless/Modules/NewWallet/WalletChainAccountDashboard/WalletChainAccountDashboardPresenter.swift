import Foundation

final class WalletChainAccountDashboardPresenter {
    weak var view: WalletChainAccountDashboardViewProtocol?
    let wireframe: WalletChainAccountDashboardWireframeProtocol
    let interactor: WalletChainAccountDashboardInteractorInputProtocol

    init(
        interactor: WalletChainAccountDashboardInteractorInputProtocol,
        wireframe: WalletChainAccountDashboardWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension WalletChainAccountDashboardPresenter: WalletChainAccountDashboardPresenterProtocol {
    func setup() {}
}

extension WalletChainAccountDashboardPresenter: WalletChainAccountDashboardInteractorOutputProtocol {}
