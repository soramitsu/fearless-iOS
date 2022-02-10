import Foundation
import SoraFoundation
import RobinHood
import SoraKeystore

final class NetworkInfoViewFactory: NetworkInfoViewFactoryProtocol {
    static func createView(
        with chain: ChainModel,
        mode: NetworkInfoMode,
        node: ChainNodeModel
    ) -> NetworkInfoViewProtocol? {
        let repository: CoreDataRepository<ChainModel, CDChain> = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
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
            repository: AnyDataProviderRepository(repository),
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
