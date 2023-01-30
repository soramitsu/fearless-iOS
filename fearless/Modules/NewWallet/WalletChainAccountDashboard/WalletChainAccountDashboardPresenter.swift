import Foundation

final class WalletChainAccountDashboardPresenter {
    weak var view: WalletChainAccountDashboardViewProtocol?
    let wireframe: WalletChainAccountDashboardWireframeProtocol
    let interactor: WalletChainAccountDashboardInteractorInputProtocol

    weak var transactionHistoryModuleInput: WalletTransactionHistoryModuleInput?
    weak var chainAccountModuleInput: ChainAssetModuleInput?

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

extension WalletChainAccountDashboardPresenter: ChainAssetModuleOutput {
    func updateTransactionHistory(for chainAsset: ChainAsset?) {
        transactionHistoryModuleInput?.updateTransactionHistory(for: chainAsset)
    }
}
