import Foundation
import SoraFoundation

struct ChainAccountViewFactory {
    static func createView(chain: ChainModel, asset: AssetModel) -> ChainAccountViewProtocol? {
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let interactor = ChainAccountInteractor(
            selectedMetaAccount: SelectedWalletSettings.shared.value,
            chain: chain,
            asset: asset,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory
        )
        let wireframe = ChainAccountWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ChainAccountViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        let presenter = ChainAccountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            logger: Logger.shared,
            asset: asset,
            chain: chain,
            selectedMetaAccount: SelectedWalletSettings.shared.value
        )

        let view = ChainAccountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
