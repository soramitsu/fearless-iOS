import Foundation
import SSFModels

final class CrossChainTxTrackingRouter: CrossChainTxTrackingRouterInput {
    func presentHistoryDetails(
        chainAsset: ChainAsset,
        transaction: AssetTransactionData,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = WalletTransactionDetailsViewFactory.createView(
            transaction: transaction,
            asset: chainAsset.asset,
            chain: chainAsset.chain,
            selectedAccount: wallet
        ) else {
            return
        }
        
        view?.controller.navigationController?.setViewControllers([module.controller], animated: true)
    }
}
