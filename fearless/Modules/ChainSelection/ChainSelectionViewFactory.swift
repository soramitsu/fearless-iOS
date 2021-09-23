import Foundation
import RobinHood

struct ChainSelectionViewFactory {
    static func createView(
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?,
        repositoryFilter: NSPredicate?
    ) -> ChainSelectionViewProtocol? {
        let mapper = ChainModelMapper()
        let repository = SubstrateDataStorageFacade.shared.createRepository(
            filter: repositoryFilter,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix],
            mapper: AnyCoreDataMapper(mapper)
        )

        let localSubscriptionFactory = WalletLocalSubscriptionFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            storageFacade: SubstrateDataStorageFacade.shared,
            operationManager: OperationManagerFacade.sharedManager,
            logger: Logger.shared
        )

        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: localSubscriptionFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = ChainSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let presenter = ChainSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: selectedChainId,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let view = ChainSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            presenter: presenter
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
