import Foundation
import SoraUI
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
    
    func complete(
        on view: ControllerBackedProtocol?,
        title: String?,
        chainAsset: ChainAsset
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        let controller = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: title)?.view.controller
        controller?.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller?.modalTransitioningFactory = factory

        view?.controller.navigationController?.dismiss(animated: true) {
            if let presenter = presenter as? ControllerBackedProtocol,
               let controller = controller {
                presenter.controller.present(controller, animated: true)
            }
        }
    }
}
