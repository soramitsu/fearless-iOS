import Foundation
import SoraFoundation
import RobinHood
import SSFModels

struct NodeSelectionViewFactory {
    static func createView(chain: ChainModel) -> NodeSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createAsyncRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = NodeSelectionInteractor(
            chain: chain,
            repository: AsyncAnyRepository(repository),
            eventCenter: EventCenter.shared,
            chainRegistry: ChainRegistryFacade.sharedRegistry
        )
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
