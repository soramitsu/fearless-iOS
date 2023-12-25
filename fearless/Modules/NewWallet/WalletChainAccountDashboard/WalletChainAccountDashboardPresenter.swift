import Foundation
import SSFModels

final class WalletChainAccountDashboardPresenter {
    weak var view: WalletChainAccountDashboardViewProtocol?
    let wireframe: WalletChainAccountDashboardWireframeProtocol
    let interactor: WalletChainAccountDashboardInteractorInputProtocol

    weak var transactionHistoryModuleInput: WalletTransactionHistoryModuleInput?
    weak var chainAccountModuleInput: ChainAccountModuleInput?
    weak var assetNetworksModuleInput: AssetNetworksModuleInput?

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

extension WalletChainAccountDashboardPresenter: ChainAccountModuleOutput {
    func updateTransactionHistory(for chainAsset: ChainAsset?) {
        transactionHistoryModuleInput?.updateTransactionHistory(for: chainAsset)
    }
}
