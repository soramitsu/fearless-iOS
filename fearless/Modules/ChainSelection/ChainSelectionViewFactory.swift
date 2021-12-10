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

        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
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

        let title = LocalizableResource { locale in
            R.string.localizable.commonSelectNetwork(
                preferredLanguages: locale.rLanguages
            )
        }

        let view = ChainSelectionViewController(
            nibName: R.nib.selectionListViewController.name,
            localizedTitle: title,
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
