import Foundation
import SoraUI
import SSFModels

final class PolkaswapSwapConfirmationRouter: PolkaswapSwapConfirmationRouterInput {
    func complete(
        on view: ControllerBackedProtocol?,
        hashString: String,
        chainAsset: ChainAsset,
        completeClosure: (() -> Void)?
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        if let controller = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: hashString, closure: {
               completeClosure?()
               view?.controller.navigationController?.popViewController(animated: true)
           })?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory
            view?.controller.present(controller, animated: true)
        }
    }
}
