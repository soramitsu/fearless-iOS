import Foundation
import SoraUI
import SSFModels

final class StakingUnbondConfirmWireframe: StakingUnbondConfirmWireframeProtocol, ModalAlertPresenting {
    func complete(
        on view: ControllerBackedProtocol?,
        hash: String,
        chainAsset: ChainAsset
    ) {
        let presenter = view?.controller.navigationController?.presentingViewController

        view?.controller.navigationController?.dismiss(animated: true, completion: nil)

        if let presenter = presenter as? ControllerBackedProtocol,
           let controller = AllDoneAssembly.configureModule(
               chainAsset: chainAsset,
               hashString: hash
           )?.view.controller {
            controller.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            controller.modalTransitioningFactory = factory
            presenter.controller.present(controller, animated: true)
        }
    }
}
