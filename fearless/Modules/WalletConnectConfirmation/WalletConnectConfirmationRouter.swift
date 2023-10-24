import Foundation
import SoraUI
import SSFModels
import SSFUtils

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
            closure: closure,
            isWalletConnectResult: true
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

    func showRawData(json: JSON, from view: ControllerBackedProtocol?) {
        let module = RawDataAssembly.configureModule(json: json)
        guard let controller = module?.view.controller else {
            return
        }
        view?.controller.present(controller, animated: true)
    }
}
