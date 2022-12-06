import UIKit
import SoraUI

protocol AllDonePresentable {
    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol)
}

extension AllDonePresentable {
    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol) {
        if let controller = AllDoneAssembly.configureModule(with: extrinsicHash)?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory
            view.controller.present(controller, animated: true)
        }
    }
}
