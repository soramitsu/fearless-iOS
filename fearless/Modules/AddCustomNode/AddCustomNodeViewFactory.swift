import Foundation
import RobinHood
import SoraFoundation

struct AddCustomNodeViewFactory {
    static func createView(chain: ChainModel, moduleOutput: AddCustomNodeModuleOutput?) -> AddCustomNodeViewProtocol? {
        let repository: CoreDataRepository<ChainModel, CDChain> = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)

        let interactor = AddCustomNodeInteractor(
            chain: chain,
            repository: AnyDataProviderRepository(repository),
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
