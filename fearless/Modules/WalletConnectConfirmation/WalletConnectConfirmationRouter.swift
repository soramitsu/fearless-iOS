import Foundation
import SoraUI
import SSFModels

final class WalletConnectConfirmationRouter: WalletConnectConfirmationRouterInput {
    func showAllDone(
        chain: ChainModel,
        hashString: String?,
        view: ControllerBackedProtocol?,
        closure: @escaping () -> Void
    ) {
        let module = AllDoneAssembly.configureModule(
            chainAsset: chain.chainAssets.first,
            hashString: hashString,
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

    func comlete(from view: ControllerBackedProtocol?) {
        guard let controller = view?.controller else {
            return
        }
        controller.view.window?.rootViewController?.dismiss(animated: false, completion: nil)
    }

    func showRawData(text: String, from view: ControllerBackedProtocol?) {
        let module = RawDataAssembly.configureModule(text: text)
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
