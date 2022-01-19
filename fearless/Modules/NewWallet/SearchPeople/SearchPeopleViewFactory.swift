import Foundation
import CommonWallet
import RobinHood
import FearlessUtils
import SoraFoundation

struct SearchPeopleViewFactory {
    static func createView(
        chain: ChainModel,
        asset: AssetModel,
        selectedMetaAccount: MetaAccountModel
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
            chain: chain,
            asset: asset,
            selectedMetaAccount: selectedMetaAccount,
            searchService: searchService
        )
        let wireframe = SearchPeopleWireframe()

        let viewModelFactory = SearchPeopleViewModelFactory(iconGenerator: PolkadotIconGenerator())

        let presenter = SearchPeoplePresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            asset: asset,
            chain: chain,
            selectedAccount: selectedMetaAccount,
            localizationManager: LocalizationManager.shared
        )

        let view = SearchPeopleViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
