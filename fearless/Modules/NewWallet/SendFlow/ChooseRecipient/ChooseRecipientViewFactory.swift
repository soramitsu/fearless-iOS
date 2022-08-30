import RobinHood
import FearlessUtils
import SoraFoundation

struct ChooseRecipientViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedMetaAccount: MetaAccountModel,
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
            selectedMetaAccount: selectedMetaAccount,
            searchService: searchService
        )
        let wireframe = ChooseRecipientWireframe()

        let viewModelFactory = ChooseRecipientViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = ChooseRecipientPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            asset: asset,
            chain: chain,
            selectedAccount: selectedMetaAccount,
            localizationManager: LocalizationManager.shared,
            qrParser: SubstrateQRParser(),
            transferFinishBlock: transferFinishBlock
        )

        let view = ChooseRecipientViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
