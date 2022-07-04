import Foundation
import RobinHood
import SoraFoundation

struct ManageAssetsViewFactory {
    static func createView(
        selectedMetaAccount: MetaAccountModel,
        chainModels: [ChainModel]
    ) -> ManageAssetsViewProtocol? {
        guard let account = SelectedWalletSettings.shared.value else {
            return nil
        }

        let facade = UserDataStorageFacade.shared

        let mapper = MetaAccountMapper()

        let accountRepository: CoreDataRepository<MetaAccountModel, CDMetaAccount> = facade.createRepository(
            filter: nil,
            sortDescriptors: [],
            mapper: AnyCoreDataMapper(mapper)
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: selectedMetaAccount
        )

        let interactor = ManageAssetsInteractor(
            selectedMetaAccount: account,
            chainModels: chainModels,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared
        )

        let wireframe = ManageAssetsWireframe()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = ManageAssetsViewModelFactory(assetBalanceFormatterFactory: assetBalanceFormatterFactory)

        let presenter = ManageAssetsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            selectedMetaAccount: selectedMetaAccount,
            filterFactory: TitleSwitchTableViewCellModelFactory(),
            localizationManager: LocalizationManager.shared
        )

        let view = ManageAssetsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
