import Foundation
import SoraFoundation

struct NodeSelectionViewFactory {
    static func createView(chain: ChainModel) -> NodeSelectionViewProtocol? {
        let interactor = NodeSelectionInteractor(chain: chain)
        let wireframe = NodeSelectionWireframe()

        let presenter = NodeSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: NodeSelectionViewModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = NodeSelectionViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
