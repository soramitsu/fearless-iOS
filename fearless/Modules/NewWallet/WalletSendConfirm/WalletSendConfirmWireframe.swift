import Foundation
import UIKit
import SoraUI

final class WalletSendConfirmWireframe: WalletSendConfirmWireframeProtocol {
    func finish(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.dismiss(
            animated: true,
            completion: nil
        )
    }

    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popViewController(animated: true)
    }

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
