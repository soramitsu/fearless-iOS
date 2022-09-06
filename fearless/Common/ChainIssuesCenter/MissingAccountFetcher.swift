import Foundation
import RobinHood

protocol MissingAccountFetcherProtocol {
    func fetchMissingAccounts(for wallet: MetaAccountModel, complection: @escaping ([ChainModel]) -> Void)
}

final class MissingAccountFetcher: MissingAccountFetcherProtocol {
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    func fetchMissingAccounts(for wallet: MetaAccountModel, complection: @escaping ([ChainModel]) -> Void) {
        let operation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        operation.completionBlock = {
            guard let result = operation.result else {
                return
            }

            switch result {
            case let .success(chains):
                let missingAccounts = chains.filter { chain in
                    wallet.fetch(for: chain.accountRequest()) == nil
                }
                complection(missingAccounts)
            case .failure:
                break
            }
        }

        operationQueue.addOperation(operation)
    }
}
