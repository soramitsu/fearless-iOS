import CommonWallet
import RobinHood
import IrohaCrypto

typealias SearchServiceSearchPeopleResultBlock = (Result<[SearchData]?, Error>) -> Void

protocol SearchServiceProtocol {
    func searchPeople(query: String, chain: ChainModel, completion: @escaping SearchServiceSearchPeopleResultBlock)
}

final class SearchService: BaseService, SearchServiceProtocol {
    private let contactsOperationFactory: WalletContactOperationFactoryProtocol
    private let accountsRepository: AnyDataProviderRepository<MetaAccountModel>

    private var searchOperation: CompoundOperationWrapper<[SearchData]?>?

    init(
        operationManager: OperationManagerProtocol,
        contactsOperationFactory: WalletContactOperationFactoryProtocol,
        accountsRepository: AnyDataProviderRepository<MetaAccountModel>
    ) {
        self.contactsOperationFactory = contactsOperationFactory
        self.accountsRepository = accountsRepository

        super.init(operationManager: operationManager)
    }

    func searchPeople(query: String, chain: ChainModel, completion: @escaping SearchServiceSearchPeopleResultBlock) {
        searchOperation?.cancel()

        let operation = searchOperation(query, chain: chain)

        operation.targetOperation.completionBlock = {
            do {
                let result = try operation.targetOperation.extractNoCancellableResultData()
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }

        searchOperation = operation

        operationManager.enqueue(operations: operation.allOperations, in: .transient)
    }
}

extension SearchService {
    func searchOperation(_ searchString: String, chain: ChainModel) -> CompoundOperationWrapper<[SearchData]?> {
        let fetchOperation = contactsOperation(chain: chain)

        let normalizedSearch = searchString.lowercased()

        let filterOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let result = try fetchOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            return result?.filter {
                ($0.firstName.lowercased().range(of: normalizedSearch) != nil) ||
                    ($0.lastName.lowercased().range(of: normalizedSearch) != nil)
            }
        }

        let dependencies = fetchOperation.allOperations
        dependencies.forEach { filterOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: filterOperation,
            dependencies: dependencies
        )
    }

    func contactsOperation(chain: ChainModel) -> CompoundOperationWrapper<[SearchData]?> {
        let accountsOperation = accountsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let contactsOperation = contactsOperationFactory.fetchContactsOperation()

        let mapOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let accounts = try accountsOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let addressFactory = SS58AddressFactory()
            let existingAddresses = accounts.compactMap { Array($0.chainAccounts) }.reduce([], +).compactMap { try? addressFactory.address(fromAccountId: $0.accountId, type: chain.addressPrefix) }

            let accountsResult = try accounts.compactMap {
                try SearchData.createFromChainAccount(
                    chain: chain,
                    account: $0,
                    addressFactory: addressFactory
                )
            }

            let contacts = try contactsOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .filter { !existingAddresses.contains($0.peerAddress) }

            let contactsResult = try contacts.map { contact in
                try SearchData.createFromContactItem(
                    contact,
                    addressPrefix: chain.addressPrefix,
                    addressFactory: addressFactory
                )
            }

            return accountsResult + contactsResult
        }

        mapOperation.addDependency(contactsOperation.targetOperation)
        mapOperation.addDependency(accountsOperation)

        let dependencies = contactsOperation.allOperations + [accountsOperation]

        return CompoundOperationWrapper(
            targetOperation: mapOperation,
            dependencies: dependencies
        )
    }
}
