import RobinHood
import FearlessUtils
import SoraFoundation

struct ChooseRecipientViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        wallet: MetaAccountModel,
        flow: SendFlow,
        transferFinishBlock: WalletTransferFinishBlock?
    ) -> ChooseRecipientViewProtocol? {
        let accountStorage: CoreDataRepository<MetaAccountModel, CDMetaAccount> =
            UserDataStorageFacade.shared
                .createRepository(
                    filter: nil,
                    sortDescriptors: [NSSortDescriptor.accountsByOrder],
                    mapper: AnyCoreDataMapper(MetaAccountMapper())
                )

        let contactsOperationFactory = WalletContactOperationFactory(
            storageFacade: SubstrateDataStorageFacade.shared,
            targetAddress: ""
        )

        let searchService = SearchService(
            operationManager: OperationManagerFacade.sharedManager,
            contactsOperationFactory: contactsOperationFactory,
            accountsRepository: AnyDataProviderRepository(accountStorage)
        )

        let interactor = ChooseRecipientInteractor(
            chain: chain,
            asset: asset,
            wallet: wallet,
            searchService: searchService
        )
        let router = ChooseRecipientRouter(flow: flow, transferFinishBlock: transferFinishBlock)

        let viewModelFactory = ChooseRecipientViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ChooseRecipientPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            asset: asset,
            chain: chain,
            wallet: wallet,
            localizationManager: LocalizationManager.shared,
            qrParser: SubstrateQRParser()
        )

        let view = ChooseRecipientViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
