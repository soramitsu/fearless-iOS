import UIKit
import RobinHood
import SSFModels

final class SelectExportAccountInteractor {
    // MARK: - Private properties

    private weak var output: SelectExportAccountInteractorOutput?
    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationManager: OperationManagerProtocol

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationManager: OperationManagerProtocol
    ) {
        self.chainRepository = chainRepository
        self.operationManager = operationManager
    }

    private func fetchData() {
        let fetchOperation = chainRepository.fetchAllOperation(with: RepositoryFetchOptions())

        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleChains(result: fetchOperation.result)
            }
        }

        operationManager.enqueue(operations: [fetchOperation], in: .transient)
    }

    private func handleChains(result: Result<[ChainModel], Error>?) {
        switch result {
        case let .success(chains):
            output?.didReceive(chains: chains)
        case .failure:
            break
        case .none:
            break
        }
    }
}

// MARK: - SelectExportAccountInteractorInput

extension SelectExportAccountInteractor: SelectExportAccountInteractorInput {
    func setup(with output: SelectExportAccountInteractorOutput) {
        self.output = output

        fetchData()
    }
}
