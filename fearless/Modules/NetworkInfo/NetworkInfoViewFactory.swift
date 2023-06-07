import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFModels

final class NetworkInfoViewFactory: NetworkInfoViewFactoryProtocol {
    static func createView(
        with chain: ChainModel,
        mode: NetworkInfoMode,
        node: ChainNodeModel
    ) -> NetworkInfoViewProtocol? {
        let facade = SubstrateDataStorageFacade.shared

        let mapper = ChainNodeModelMapper()

        let nodeRepository: CoreDataRepository<ChainNodeModel, CDChainNode> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let view = NetworkInfoViewController(nib: R.nib.networkInfoViewController)
        let presenter = NetworkInfoPresenter(
            chain: chain,
            node: node,
            mode: mode,
            localizationManager: LocalizationManager.shared
        )

        let substrateOperationFactory = SubstrateOperationFactory(logger: Logger.shared)
        let interactor = NetworkInfoInteractor(
            chain: chain,
            nodeRepository: AnyDataProviderRepository(nodeRepository),
            substrateOperationFactory: substrateOperationFactory,
            operationManager: OperationManagerFacade.sharedManager,
            eventCenter: EventCenter.shared
        )
        let wireframe = NetworkInfoWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
