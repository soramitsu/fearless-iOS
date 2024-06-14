import Foundation
import SoraUI
import SSFModels
import SSFPools

final class LiquidityPoolRemoveLiquidityRouter: LiquidityPoolRemoveLiquidityRouterInput {
    func showConfirmation(
        chain: ChainModel,
        wallet: MetaAccountModel,
        liquidityPair: LiquidityPair,
        info: RemoveLiquidityInfo,
        from view: ControllerBackedProtocol?
    ) {
        guard let module = LiquidityPoolRemoveLiquidityConfirmAssembly.configureModule(wallet: wallet, chain: chain, liquidityPair: liquidityPair, removeInfo: info) else {
            return
        }

        view?.controller.navigationController?.pushViewController(module.view.controller, animated: true)
    }

    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
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
