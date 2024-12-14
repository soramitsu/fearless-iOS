import Foundation
import SSFModels

final class CrossChainSwapConfirmRouter: CrossChainSwapConfirmRouterInput {
    func presentStatusTrackingScreen(
        transaction: AssetTransactionData,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = CrossChainTxTrackingAssembly.configureModule(
            transaction: transaction,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return
        }

        let presenter = view?.controller.navigationController?.presentingViewController

        view?.controller.navigationController?.dismiss(animated: true) {
            if let presenter = presenter as? ControllerBackedProtocol {
                let controller = module.view.controller
                presenter.controller.present(controller, animated: true)
            }
        }
    }
}
