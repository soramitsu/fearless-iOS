import Foundation

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
}
