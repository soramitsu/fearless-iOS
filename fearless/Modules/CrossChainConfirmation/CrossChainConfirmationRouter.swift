import Foundation
import SoraUI
import SSFModels

final class CrossChainConfirmationRouter: CrossChainConfirmationRouterInput {
    func complete(
        on view: ControllerBackedProtocol?,
        hash: String?,
        title: String,
        description: String,
        chainAsset: ChainAsset
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        let controller = AllDoneAssembly.configureModule(
            chainAsset: chainAsset,
            hashString: hash,
            title: title,
            description: description
        )?.view.controller
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
