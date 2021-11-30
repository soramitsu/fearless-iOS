import Foundation
import RobinHood
import SoraFoundation

struct ChainAccountBalanceListViewFactory {
    static func createView() -> ChainAccountBalanceListViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let interactor = ChainAccountBalanceListInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            repository: AnyDataProviderRepository(repository),
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )

        let wireframe = ChainAccountBalanceListWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()

        let localizationManager = LocalizationManager.shared

        let presenter = ChainAccountBalanceListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            localizationManager: localizationManager
        )

        let view = ChainAccountBalanceListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
