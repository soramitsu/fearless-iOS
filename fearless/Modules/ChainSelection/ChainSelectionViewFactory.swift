import Foundation
import RobinHood
import SoraFoundation

struct ChainSelectionViewFactory {
    static func createView(
        delegate: ChainSelectionDelegate,
        selectedChainId: ChainModel.Id?,
        repositoryFilter: NSPredicate?
    ) -> ChainSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            for: repositoryFilter,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
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

        let localizationManager = LocalizationManager.shared

        let presenter = ChainSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedChainId: selectedChainId,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )

        let view = ChainSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
