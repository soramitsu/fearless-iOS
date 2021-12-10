import Foundation
import RobinHood
import SoraFoundation

struct AssetSelectionViewFactory {
    static func createView(
        delegate: AssetSelectionDelegate,
        selectedChainId: ChainAssetId?,
        assetFilter: @escaping AssetSelectionFilter
    ) -> ChainSelectionViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            for: nil,
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let interactor = ChainSelectionInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = AssetSelectionWireframe()
        wireframe.delegate = delegate

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = AssetSelectionPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetFilter: assetFilter,
            selectedChainAssetId: selectedChainId,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )

        let title = LocalizableResource { locale in
            R.string.localizable.commonSelectAsset(preferredLanguages: locale.rLanguages)
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
