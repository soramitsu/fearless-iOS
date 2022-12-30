import Foundation
import SoraUI

final class PolkaswapSwapConfirmationRouter: PolkaswapSwapConfirmationRouterInput {
    func complete(
        on view: ControllerBackedProtocol?,
        title: String,
        chainAsset: ChainAsset
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        view?.controller.navigationController?.dismiss(animated: true, completion: nil)

        if let presenter = presenter as? ControllerBackedProtocol,
           let controller = AllDoneAssembly.configureModule(with: title, chainAsset: chainAsset)?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory
            presenter.controller.present(controller, animated: true)
        }
    }
}
