import Foundation
import SSFModels
import SoraUI

final class LiquidityPoolSupplyConfirmRouter: LiquidityPoolSupplyConfirmRouterInput {
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

        view?.controller.navigationController?.popToRootViewController(animated: true)
        if let controller = controller {
            view?.controller.navigationController?.present(controller, animated: true)
        }
    }
}
