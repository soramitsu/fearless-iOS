import Foundation

final class NodeSelectionWireframe: NodeSelectionWireframeProtocol {
    func presentAddNodeFlow(
        with _: ChainModel,
        moduleOutput _: AddCustomNodeModuleOutput?,
        from view: ControllerBackedProtocol?
    ) {
        guard let controller = AddCustomNodeViewFactory.createView()?.controller else {
            return
        }

        view?.controller.present(controller, animated: true)
    }
}
