import Foundation
import SoraFoundation
import RobinHood

struct NodeSelectionViewFactory {
    static func createView(chain: ChainModel) -> NodeSelectionViewProtocol? {
        let repository: CoreDataRepository<ChainModel, CDChain> = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = NodeSelectionInteractor(
            chain: chain,
            repository: AnyDataProviderRepository(repository),
            operationManager: OperationManagerFacade.sharedManager
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
