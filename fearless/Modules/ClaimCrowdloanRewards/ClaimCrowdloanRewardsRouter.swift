import Foundation
import SSFModels
import SoraUI

final class ClaimCrowdloanRewardsRouter: ClaimCrowdloanRewardsRouterInput {
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    ) {
        let presenter = view?.controller.presentingViewController

        let controller = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: title)?.view.controller
        controller?.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller?.modalTransitioningFactory = factory

        view?.controller.dismiss(animated: true) {
            if let presenter = presenter as? ControllerBackedProtocol,
               let controller = controller {
                presenter.controller.present(controller, animated: true)
            }
        }
    }
}
