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
            MainTransitionHelper.transitToMainTabBarController(closing: view.controller, animated: true)
            return
        }

        let presenter = view.controller.navigationController?.presentingViewController

        guard let controller = AllDoneAssembly.configureModule(chainAsset: chainAsset, hashString: title)?.view.controller else {
            return
        }

        controller.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller.modalTransitioningFactory = factory

        MainTransitionHelper.transitToMainTabBarController(closing: view.controller, animated: true) { _ in
            if let presenter = presenter as? ControllerBackedProtocol {
                presenter.controller.present(controller, animated: true)
            }
        }
    }
}
