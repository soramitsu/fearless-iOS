import CommonWallet
import RobinHood
import IrohaCrypto
import SSFModels

enum SearchServiceError: Error {
    case addressInvalid
}

typealias SearchServiceSearchPeopleResultBlock = (Result<[SearchData]?, Error>) -> Void

protocol SearchServiceProtocol {
    @discardableResult
    func searchPeople(
        query: String,
        chain: ChainModel,
        filterResults: ((SearchData) -> Bool)?,
        completion: @escaping SearchServiceSearchPeopleResultBlock
    ) -> CancellableCall
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

    @discardableResult
    func searchPeople(
        query: String,
        chain: ChainModel,
        filterResults: ((SearchData) -> Bool)? = nil,
        completion: @escaping SearchServiceSearchPeopleResultBlock
    ) -> CancellableCall {
        searchOperation?.cancel()

        let operation = searchOperation(query, chain: chain, filterResults: filterResults)

        operation.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                do {
                    let result = try operation.targetOperation.extractNoCancellableResultData()
                    completion(.success(result))
                } catch {
                    completion(.failure(error))
                }
            }
        }

        searchOperation = operation

        operationManager.enqueue(operations: operation.allOperations, in: .transient)

        return operation
    }
}

extension SearchService {
    func searchOperation(
        _ searchString: String,
        chain: ChainModel,
        filterResults: ((SearchData) -> Bool)? = nil
    ) -> CompoundOperationWrapper<[SearchData]?> {
        let fetchOperation = contactsOperation(chain: chain, filterResults: filterResults)

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

    func contactsOperation(
        chain: ChainModel,
        filterResults: ((SearchData) -> Bool)? = nil
    ) -> CompoundOperationWrapper<[SearchData]?> {
        let accountsOperation = accountsRepository.fetchAllOperation(with: RepositoryFetchOptions())
        let contactsOperation = contactsOperationFactory.fetchContactsOperation()

        let mapOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let accounts = try accountsOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            func address(accountId: AccountId) -> AccountAddress? {
                let chainFormat: ChainFormat = chain.isEthereumBased ? .ethereum : .substrate(chain.addressPrefix)
                return try? accountId.toAddress(using: chainFormat)
            }

            var existingAddresses = accounts
                .compactMap { Array($0.chainAccounts) }.reduce([], +)
                .compactMap { try? AddressFactory.address(for: $0.accountId, chain: chain) }

            if let selectedAccount = SelectedWalletSettings.shared.value,
               let accountId = selectedAccount.fetch(for: chain.accountRequest())?.accountId,
               let address = try? AddressFactory.address(for: accountId, chain: chain) {
                existingAddresses.append(address)
            }

            let accountsResult = try accounts.compactMap {
                try SearchData.createFromChainAccount(
                    chain: chain,
                    account: $0
                )
            }

            let contacts = try contactsOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .filter { !existingAddresses.contains($0.peerAddress) }

            let contactsResult = try contacts.map { contact in
                try SearchData.createFromContactItem(
                    contact,
                    chain: chain
                )
            }

            let mergedResults = accountsResult + contactsResult

            guard let filterResults = filterResults else {
                return mergedResults
            }

            return mergedResults.filter(filterResults)
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
