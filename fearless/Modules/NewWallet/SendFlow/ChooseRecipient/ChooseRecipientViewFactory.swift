import RobinHood
import FearlessUtils
import SoraFoundation

struct ChooseRecipientViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: SendFlow,
        transferFinishBlock: WalletTransferFinishBlock?,
        address: String? = nil
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

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper: CodableCoreDataMapper<ScamInfo, CDScamInfo> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDScamInfo.address))

        let repository: CoreDataRepository<ScamInfo, CDScamInfo> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let scamServiceOperationFactory = ScamServiceOperationFactory(
            repository: AnyDataProviderRepository(repository)
        )

        let interactor = ChooseRecipientInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            searchService: searchService,
            scamServiceOperationFactory: scamServiceOperationFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let router = ChooseRecipientRouter(flow: flow, transferFinishBlock: transferFinishBlock)

        let viewModelFactory = ChooseRecipientViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ChooseRecipientPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: LocalizationManager.shared,
            qrParser: SubstrateQRParser(),
            address: address
        )

        let view = ChooseRecipientViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
