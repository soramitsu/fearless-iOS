import UIKit
import SoraFoundation
import RobinHood

final class ContactsAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    ) -> ContactsModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let repositoryFacade = SubstrateDataStorageFacade.shared
        let mapper: CodableCoreDataMapper<Contact, CDContact> =
            CodableCoreDataMapper(entityIdentifierFieldName: #keyPath(CDContact.address))

        let repository: CoreDataRepository<Contact, CDContact> =
            repositoryFacade.createRepository(
                filter: nil,
                sortDescriptors: [],
                mapper: AnyCoreDataMapper(mapper)
            )

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let operationFactory = HistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))

        let interactor = ContactsInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            historyOperationFactory: operationFactory,
            wallet: wallet,
            chainAsset: chainAsset
        )
        let router = ContactsRouter()

        let presenter = ContactsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: AddressBookViewModelFactory(),
            moduleOutput: moduleOutput,
            chain: chainAsset.chain,
            wallet: wallet
        )

        let view = ContactsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
