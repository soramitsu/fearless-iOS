import CommonWallet
import RobinHood
import IrohaCrypto

enum SearchServiceError: Error {
    case addressInvalid
}

typealias SearchServiceSearchPeopleResultBlock = (Result<[SearchData]?, Error>) -> Void

protocol SearchServiceProtocol {
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
        let addressCheckOperation: BaseOperation<Bool> = ClosureOperation {
            (try? SS58AddressFactory().type(fromAddress: searchString).uint16Value == chain.addressPrefix) == true
        }
        let fetchOperation = contactsOperation(chain: chain, filterResults: filterResults)

        let normalizedSearch = searchString.lowercased()

        let filterOperation: BaseOperation<[SearchData]?> = ClosureOperation {
            let addressValid = try? addressCheckOperation.extractNoCancellableResultData()

            let result = try fetchOperation.targetOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            if let addressValid = addressValid, addressValid == false, result?.isEmpty == false {
                throw SearchServiceError.addressInvalid
            }

            return result?.filter {
                ($0.firstName.lowercased().range(of: normalizedSearch) != nil) ||
                    ($0.lastName.lowercased().range(of: normalizedSearch) != nil)
            }
        }

        let dependencies = [addressCheckOperation] + fetchOperation.allOperations
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

            let addressFactory = SS58AddressFactory()
            var existingAddresses = accounts
                .compactMap { Array($0.chainAccounts) }.reduce([], +)
                .compactMap { try? addressFactory.address(fromAccountId: $0.accountId, type: chain.addressPrefix) }

            if let selectedAccount = SelectedWalletSettings.shared.value,
               let accountId = selectedAccount.fetch(for: chain.accountRequest())?.accountId,
               let address = try? addressFactory.address(fromAccountId: accountId, type: chain.addressPrefix) {
                existingAddresses.append(address)
            }

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
