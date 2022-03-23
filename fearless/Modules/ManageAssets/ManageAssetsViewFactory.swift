import Foundation
import RobinHood

struct ManageAssetsViewFactory {
    static func createView(selectedMetaAccount: MetaAccountModel) -> ManageAssetsViewProtocol? {
        let repository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: selectedMetaAccount
        )

        let interactor = ManageAssetsInteractor(
            selectedMetaAccount: selectedMetaAccount,
            repository: AnyDataProviderRepository(repository),
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = ManageAssetsWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ManageAssetsViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        let presenter = ManageAssetsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory
        )

        let view = ManageAssetsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
