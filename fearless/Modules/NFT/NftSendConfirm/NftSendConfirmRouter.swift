import Foundation
import SSFModels
import SoraUI

final class NftSendConfirmRouter: NftSendConfirmRouterInput {
    func complete(
        on view: ControllerBackedProtocol,
        title: String,
        chainAsset: ChainAsset?
    ) {
        guard let chainAsset = chainAsset else {
            view.controller.navigationController?.dismiss(animated: true)
            return
        }

        let presenter = view.controller.navigationController?.presentingViewController

        let controller = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: title)?.view.controller
        controller?.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller?.modalTransitioningFactory = factory

        view.controller.navigationController?.dismiss(animated: true) {
            if let presenter = presenter as? ControllerBackedProtocol,
               let controller = controller {
                presenter.controller.present(controller, animated: true)
            }
        }
    }
}
