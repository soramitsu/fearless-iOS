import UIKit
import SoraFoundation
import RobinHood
import SSFModels

final class ContactsAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        moduleOutput: ContactsModuleOutput
    ) -> ContactsModuleCreationResult? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()
        let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId)

        guard
            let historyOperationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chainAsset: chainAsset,
                txStorage: AnyDataProviderRepository(txStorage),
                runtimeService: runtimeService
            )
        else {
            return nil
        }

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

        let interactor = ContactsInteractor(
            repository: AnyDataProviderRepository(repository),
            operationQueue: OperationQueue(),
            historyOperationFactory: historyOperationFactory,
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
