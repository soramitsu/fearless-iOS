import Foundation
import RobinHood
import SoraFoundation
import SSFModels

struct AddCustomNodeViewFactory {
    static func createView(chain: ChainModel, moduleOutput: AddCustomNodeModuleOutput?) -> AddCustomNodeViewProtocol? {
        let repository: CoreDataRepository<ChainModel, CDChain> = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let facade = SubstrateDataStorageFacade.shared

        let mapper = ChainNodeModelMapper()

        let nodeRepository: CoreDataRepository<ChainNodeModel, CDChainNode> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)

        let interactor = AddCustomNodeInteractor(
            chain: chain,
            repository: AnyDataProviderRepository(repository),
            nodeRepository: AnyDataProviderRepository(nodeRepository),
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared,
            substrateOperationFactory: substrateOperationFactory
        )
        let wireframe = AddCustomNodeWireframe()

        let presenter = AddCustomNodePresenter(
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: LocalizationManager.shared,
            moduleOutput: moduleOutput
        )

        let view = AddCustomNodeViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
