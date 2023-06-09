import UIKit
import RobinHood
import SSFModels

final class SelectNetworkInteractor {
    // MARK: - Private properties

    private weak var output: SelectNetworkInteractorOutput?

    private let repository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let chainModels: [ChainModel]?

    init(
        output: SelectNetworkInteractorOutput? = nil,
        repository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue,
        chainModels: [ChainModel]?
    ) {
        self.output = output
        self.repository = repository
        self.operationQueue = operationQueue
        self.chainModels = chainModels
    }

    private func fetchChains() {
        if let chainModels = chainModels {
            handleChains(result: .success(chainModels))
            return
        }
        let fetchOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationQueue.addOperation(fetchOperation)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            output?.didReceiveChains(result: .success(chains))
        case let .failure(error):
            output?.didReceiveChains(result: .failure(error))
        case .none:
            output?.didReceiveChains(result: .failure(BaseOperationError.parentOperationCancelled))
        }
    }
}

// MARK: - SelectNetworkInteractorInput

extension SelectNetworkInteractor: SelectNetworkInteractorInput {
    func setup(with output: SelectNetworkInteractorOutput) {
        self.output = output
        fetchChains()
    }
}
