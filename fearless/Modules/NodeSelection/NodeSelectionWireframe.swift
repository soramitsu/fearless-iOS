import Foundation
import SSFModels

final class NodeSelectionWireframe: NodeSelectionWireframeProtocol {
    func presentAddNodeFlow(
        with chain: ChainModel,
        moduleOutput: AddCustomNodeModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = AddCustomNodeViewFactory.createView(chain: chain, moduleOutput: moduleOutput)?.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }

    func presentNodeInfo(
        chain: ChainModel,
        node: ChainNodeModel,
        mode: NetworkInfoMode,
        from view: ControllerBackedProtocol?
    ) {
        guard let networkInfoView = NetworkInfoViewFactory.createView(
            with: chain,
            mode: mode,
            node: node
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: networkInfoView.controller)
        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
