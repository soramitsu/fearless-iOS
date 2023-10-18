import Foundation
import SoraUI
import SSFModels

final class WalletConnectProposalRouter: WalletConnectProposalRouterInput {
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

    func showMultiSelect(
        canSelect: Bool,
        dataSource: [ChainModel],
        selectedChains: [ChainModel.Id]?,
        moduleOutput: MultiSelectNetworksModuleOutput?,
        view: ControllerBackedProtocol?
    ) {
        let module = MultiSelectNetworksAssembly.configureModule(
            canSelect: canSelect,
            dataSource: dataSource,
            selectedChains: selectedChains,
            moduleOutput: moduleOutput
        )
        guard let controller = module?.view.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }
}
