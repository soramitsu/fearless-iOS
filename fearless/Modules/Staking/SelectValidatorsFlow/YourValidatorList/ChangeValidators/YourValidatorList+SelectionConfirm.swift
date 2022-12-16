import Foundation
import SoraUI

extension YourValidatorList {
    final class SelectValidatorsConfirmWireframe: SelectValidatorsConfirmWireframeProtocol, ModalAlertPresenting, AllDonePresentable {
        func complete(txHash: String, from view: SelectValidatorsConfirmViewProtocol?) {
            let presenter = view?.controller.navigationController?.presentingViewController
            let navigationController = view?.controller.navigationController

            let allDoneController = AllDoneAssembly.configureModule(with: txHash)?.view.controller
            allDoneController?.modalPresentationStyle = .custom

            let factory = ModalSheetBlurPresentationFactory(
                configuration: ModalSheetPresentationConfiguration.fearlessBlur
            )
            allDoneController?.modalTransitioningFactory = factory

            navigationController?.dismiss(animated: true, completion: {
                if let presenter = presenter as? ControllerBackedProtocol, let allDoneController = allDoneController {
                    presenter.controller.present(allDoneController, animated: true)
                }
            })
        }
    }
}
