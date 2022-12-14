import UIKit
import SoraUI

protocol AllDonePresentable {
    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol)
    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol, closure: (() -> Void)?)
}

extension AllDonePresentable {
    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol, closure: (() -> Void)? = nil) {
        if let controller = AllDoneAssembly.configureModule(with: extrinsicHash, closure: closure)?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory

            let presentingViewController = view.controller.presentedViewController ?? view.controller
            presentingViewController.present(controller, animated: true)
        }
    }

    func presentDone(extrinsicHash: String, from view: ControllerBackedProtocol) {
        presentDone(extrinsicHash: extrinsicHash, from: view, closure: nil)
    }
}
