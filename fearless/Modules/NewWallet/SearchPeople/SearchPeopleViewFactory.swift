import Foundation
import CommonWallet
import RobinHood
import FearlessUtils
import SoraFoundation

struct SearchPeopleViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        scamInfo: ScamInfo?,
        transferFinishBlock: WalletTransferFinishBlock?
    ) -> SearchPeopleViewProtocol? {
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

        let interactor = SearchPeopleInteractor(
            chainAsset: chainAsset,
            wallet: wallet,
            searchService: searchService
        )
        let wireframe = SearchPeopleWireframe()

        let viewModelFactory = SearchPeopleViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = SearchPeoplePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset,
            wallet: wallet,
            localizationManager: LocalizationManager.shared,
            qrParser: SubstrateQRParser(),
            scamInfo: scamInfo,
            transferFinishBlock: transferFinishBlock
        )

        let view = SearchPeopleViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
