import UIKit
import SoraFoundation
import RobinHood
import SSFModels

enum ContactSource {
    case token(chainAsset: ChainAsset)
    case nft(chain: ChainModel)

    var chain: ChainModel {
        switch self {
        case let .token(chainAsset):
            return chainAsset.chain
        case let .nft(chain):
            return chain
        }
    }
}

enum ContactsAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        source: ContactSource,
        moduleOutput: ContactsModuleOutput
    ) -> ContactsModuleCreationResult? {
        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        guard
            let historyOperationFactory = HistoryOperationFactoriesAssembly.createOperationFactory(
                chain: source.chain,
                txStorage: AnyDataProviderRepository(txStorage)
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
            source: source
        )
        let router = ContactsRouter()

        let presenter = ContactsPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            viewModelFactory: AddressBookViewModelFactory(),
            moduleOutput: moduleOutput,
            source: source,
            wallet: wallet
        )

        let view = ContactsViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
