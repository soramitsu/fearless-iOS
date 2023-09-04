import Foundation
import SoraUI

final class WalletConnectSessionRouter: WalletConnectSessionRouterInput {
    func showAllDone(
        title: String,
        description: String,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    ) {
        let module = AllDoneAssembly.configureModule(
            chainAsset: nil,
            hashString: nil,
            title: title,
            description: description,
            closure: closure
        )
        guard let controller = module?.view.controller else {
            return
        }
        controller.modalPresentationStyle = .custom
        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        controller.modalTransitioningFactory = factory

        view?.controller.present(controller, animated: true)
    }

    func showConfirmation(
        inputData: WalletConnectConfirmationInputData,
        from view: ControllerBackedProtocol?
    ) {
        let module = WalletConnectConfirmationAssembly.configureModule(inputData: inputData)
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
