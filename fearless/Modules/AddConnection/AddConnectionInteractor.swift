import UIKit
import RobinHood
import IrohaCrypto

final class AddConnectionInteractor {
    weak var presenter: AddConnectionInteractorOutputProtocol!

    private let repository: AnyDataProviderRepository<ManagedConnectionItem>
    private let operationManager: OperationManagerProtocol
    private let substrateOperationFactory: SubstrateOperationFactoryProtocol

    init(repository: AnyDataProviderRepository<ManagedConnectionItem>,
         operationManager: OperationManagerProtocol,
         substrateOperationFactory: SubstrateOperationFactoryProtocol) {
        self.repository = repository
        self.operationManager = operationManager
        self.substrateOperationFactory = substrateOperationFactory
    }

    private func handleAdd(result: Result<Void, Error>?, for url: URL) {
        switch result {
        case .success:
            presenter.didCompleteAdding(url: url)
        case .failure(let error):
            presenter.didReceiveError(error: error, for: url)
        case .none:
            presenter.didReceiveError(error: BaseOperationError.parentOperationCancelled,
                                      for: url)
        }
    }
}

extension AddConnectionInteractor: AddConnectionInteractorInputProtocol {
    func addConnection(url: URL, name: String) {
        guard ConnectionItem.supportedConnections.first(where: { $0.url == url }) == nil else {
            presenter.didReceiveError(error: AddConnectionError.alreadyExists, for: url)
            return
        }

        presenter.didStartAdding(url: url)

        let searchOptions = RepositoryFetchOptions(includesProperties: false, includesSubentities: false)
        let searchOperation = repository.fetchOperation(by: url.absoluteString, options: searchOptions)

        let maxRequest = RepositorySliceRequest(offset: 0, count: 1, reversed: true)
        let maxOptions = RepositoryFetchOptions(includesProperties: true, includesSubentities: false)
        let maxOrderOperation = repository.fetchOperation(by: maxRequest, options: maxOptions)

        let fetchNetworkOperation = substrateOperationFactory.fetchChainOperation(url)

        let saveOperation = repository.saveOperation({
            guard case .success(let rawType) = fetchNetworkOperation.result else {
                throw AddConnectionError.invalidConnection
            }

            guard let chain = Chain(rawValue: rawType) else {
                throw AddConnectionError.unsupportedChain(SNAddressType.supported)
            }

            guard try searchOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled) == nil else {
                throw AddConnectionError.alreadyExists
            }

            let maxOrder = try maxOrderOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .first?.order
            ?? 0

            let connectionItem = ManagedConnectionItem(title: name,
                                                       url: url,
                                                       type: SNAddressType(chain: chain),
                                                       order: maxOrder + 1)

            return [connectionItem]

        }, { [] })

        saveOperation.addDependency(searchOperation)
        saveOperation.addDependency(maxOrderOperation)
        saveOperation.addDependency(fetchNetworkOperation)

        saveOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.handleAdd(result: saveOperation.result, for: url)
            }
        }

        let operations = [searchOperation, maxOrderOperation, fetchNetworkOperation, saveOperation]
        operationManager.enqueue(operations: operations,
                                 in: .transient)
    }
}
