import Foundation
import UIKit
import SSFModels

final class WalletTransactionHistoryWireframe: WalletTransactionHistoryWireframeProtocol {
    func showTransactionDetails(
        from view: ControllerBackedProtocol?,
        transaction: AssetTransactionData,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let module = CrossChainTxTrackingAssembly.configureModule(
            transaction: transaction,
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: selectedAccount
        ) else {
            return
        }
        view?.controller.present(module.view.controller, animated: true)

//        let transactionType = TransactionType(rawValue: transaction.type)
//
//        let controller: UIViewController
//        switch transactionType {
//        case .swap:
//            guard let module = SwapTransactionDetailAssembly.configureModule(
//                wallet: selectedAccount,
//                chainAsset: ChainAsset(chain: chain, asset: asset),
//                transaction: transaction
//            ) else {
//                return
//            }
//            controller = module.view.controller
//        default:
//            guard let module = WalletTransactionDetailsViewFactory.createView(
//                transaction: transaction,
//                asset: asset,
//                chain: chain,
//                selectedAccount: selectedAccount
//            ) else {
//                return
//            }
//            controller = module.controller
//        }
//
//        view?.controller.present(controller, animated: true)
    }
}
